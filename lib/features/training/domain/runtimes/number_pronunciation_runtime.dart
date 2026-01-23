import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../learning_language.dart';
import '../services/answer_matcher.dart';
import '../services/card_timer.dart';
import '../services/sound_wave_service.dart';
import '../services/speech_service.dart';
import '../task_runtime.dart';
import '../task_state.dart';
import '../tasks/number_pronunciation_task.dart';
import '../training_outcome.dart';

class NumberPronunciationRuntime extends TaskRuntimeBase {
  NumberPronunciationRuntime({
    required NumberPronunciationTask task,
    required SpeechServiceBase speechService,
    required SoundWaveServiceBase soundWaveService,
    required CardTimerBase cardTimer,
    required Duration cardDuration,
    required String? hintText,
    required void Function(bool ready, String? errorMessage) onSpeechReady,
  })  : _task = task,
        _speechService = speechService,
        _soundWaveService = soundWaveService,
        _cardTimer = cardTimer,
        _cardDuration = cardDuration,
        _hintText = hintText,
        _onSpeechReady = onSpeechReady,
        super(
          NumberPronunciationState(
            taskId: task.id,
            numberValue: task.numberValue,
            displayText: task.displayText,
            timer: TimerState(
              isRunning: false,
              duration: cardDuration,
              remaining: cardDuration,
            ),
            expectedTokens: const <String>[],
            matchedTokens: const <bool>[],
            hintText: hintText,
            isListening: false,
            speechReady: false,
          ),
        );

  static const Duration _listenRestartDelay = Duration(milliseconds: 500);
  static const int _maxConsecutiveClientErrors = 3;

  final NumberPronunciationTask _task;
  final SpeechServiceBase _speechService;
  final SoundWaveServiceBase _soundWaveService;
  final CardTimerBase _cardTimer;
  final Duration _cardDuration;
  final String? _hintText;
  final void Function(bool ready, String? errorMessage) _onSpeechReady;
  final AnswerMatcher _answerMatcher = AnswerMatcher();

  int _attemptCounter = 0;
  int? _activeAttemptId;
  String _lastPartialResult = '';
  bool _forceDefaultLocale = false;
  bool _suppressNextClientError = false;
  int _consecutiveClientErrors = 0;
  bool _speechReady = false;
  bool _cardActive = false;
  bool _isListening = false;
  bool _reportedInteraction = false;
  bool _disposed = false;

  @override
  Future<void> start() async {
    if (_disposed) return;
    _resetMatcher();
    _cardActive = true;
    _reportedInteraction = false;
    _forceDefaultLocale = false;
    _suppressNextClientError = false;
    _consecutiveClientErrors = 0;

    final ready = await _initSpeech();
    if (!ready) {
      return;
    }

    _startCardTimer();
    await _startListening();
  }

  @override
  Future<void> handleAction(TaskAction action) async {
    if (action is RetrySpeechInitAction) {
      await _initSpeech();
    }
  }

  @override
  Future<void> onTimerTimeout() async {
    if (!_cardActive) return;
    await _complete(TrainingOutcome.timeout);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _stopAttempt(stopTimer: true);
    await super.dispose();
  }

  void _resetMatcher() {
    _answerMatcher.reset(prompt: _task.prompt, answers: _task.answers);
    emitState(_buildState());
    if (_task.prompt.trim().isNotEmpty) {
      _log(
        'Speech expected: "${_task.prompt}" (lang: ${_task.language.code}, '
        'answers: ${_task.answers.join(", ")})',
      );
    }
  }

  NumberPronunciationState _buildState() {
    return NumberPronunciationState(
      taskId: _task.id,
      numberValue: _task.numberValue,
      displayText: _task.displayText,
      timer: _timerSnapshot(),
      expectedTokens: List<String>.unmodifiable(_answerMatcher.expectedTokens),
      matchedTokens: List<bool>.unmodifiable(_answerMatcher.matchedTokens),
      hintText: _hintText,
      isListening: _isListening,
      speechReady: _speechReady,
    );
  }

  TimerState _timerSnapshot() {
    return TimerState(
      isRunning: _cardTimer.isRunning,
      duration: _cardTimer.duration,
      remaining: _cardTimer.remaining(),
    );
  }

  Future<bool> _initSpeech() async {
    final result = await _speechService.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    _speechReady = result.ready;
    _onSpeechReady(result.ready, result.errorMessage);
    emitState(_buildState());
    if (!result.ready) {
      final message = result.errorMessage ??
          'Speech recognition is not available on this device.';
      emitEvent(TaskError(message));
      return false;
    }
    return true;
  }

  void _startCardTimer() {
    _cardTimer.start(_cardDuration, _onTimerTimeout);
    emitState(_buildState());
  }

  Future<void> _startListening() async {
    if (!_cardActive) return;
    final remaining = _remainingCardDuration();
    if (remaining < const Duration(milliseconds: 500)) {
      await _complete(TrainingOutcome.timeout);
      return;
    }

    final attemptId = ++_attemptCounter;
    _activeAttemptId = attemptId;
    _lastPartialResult = '';
    _suppressNextClientError = false;

    final localeId = _resolveLocaleId(_task.language);
    final listenMode = _resolveListenMode();
    _log(
      'Speech listen: remaining=${remaining.inMilliseconds}ms '
      'locale=${localeId ?? "system"} mode=$listenMode',
    );

    _soundWaveService.start();
    _isListening = true;
    emitState(_buildState());

    try {
      await _speechService.listen(
        onResult: (result) => _onSpeechResult(result, attemptId),
        onSoundLevelChange: _soundWaveService.onSoundLevel,
        listenFor: remaining,
        pauseFor: remaining,
        localeId: localeId,
        listenMode: listenMode,
        partialResults: true,
      );
      _log('Speech listen started: isListening=${_speechService.isListening}');
    } catch (error) {
      _isListening = false;
      emitState(_buildState());
      emitEvent(const TaskError('Speech recognition failed to start.'));
      await _stopAttempt(stopTimer: true);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result, int attemptId) {
    if (_activeAttemptId != attemptId) return;
    _consecutiveClientErrors = 0;
    final recognizedWords = result.recognizedWords;
    if (recognizedWords.trim().isNotEmpty) {
      _reportUserInteraction();
    }
    if (!result.finalResult) {
      if (recognizedWords.trim().isNotEmpty &&
          recognizedWords != _lastPartialResult) {
        _lastPartialResult = recognizedWords;
        _log('Speech partial: "$recognizedWords"');
      }
      return;
    }
    final resolvedWords = recognizedWords.trim().isEmpty
        ? _lastPartialResult
        : recognizedWords;
    _lastPartialResult = '';
    unawaited(
      _handleAttemptResult(recognizedText: resolvedWords),
    );
  }

  Future<void> _handleAttemptResult({
    required String recognizedText,
  }) async {
    var resolvedText = recognizedText;
    if (resolvedText.trim().isEmpty && _lastPartialResult.isNotEmpty) {
      resolvedText = _lastPartialResult;
    }
    _lastPartialResult = '';
    _log('Speech recognized: "$resolvedText"');
    if (resolvedText.trim().isNotEmpty) {
      _reportUserInteraction();
    }
    final attemptId = _activeAttemptId;
    if (attemptId == null) return;
    _activeAttemptId = null;

    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _isListening = false;
    emitState(_buildState());

    final didMatch = _answerMatcher.applyRecognition(resolvedText);
    if (didMatch) {
      emitState(_buildState());
    }

    if (_answerMatcher.isComplete) {
      await _complete(TrainingOutcome.success);
      return;
    }

    if (!_cardActive) return;
    if (_remainingCardDuration() <= Duration.zero) {
      await _complete(TrainingOutcome.timeout);
      return;
    }
    await Future.delayed(_listenRestartDelay);
    await _startListening();
  }

  Future<void> _onTimerTimeout() async {
    await onTimerTimeout();
  }

  Future<void> _complete(TrainingOutcome outcome) async {
    if (!_cardActive) return;
    _cardActive = false;
    _activeAttemptId = null;
    _cardTimer.stop();
    _soundWaveService.stop();
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _isListening = false;
    emitState(_buildState());
    emitEvent(TaskCompleted(outcome));
  }

  Future<void> _stopAttempt({bool stopTimer = false}) async {
    _activeAttemptId = null;
    _lastPartialResult = '';
    _isListening = false;
    _soundWaveService.stop();
    if (stopTimer) {
      _cardTimer.stop();
    }
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    emitState(_buildState());
  }

  void _reportUserInteraction() {
    if (_reportedInteraction) return;
    _reportedInteraction = true;
    emitEvent(const TaskUserInteracted());
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _log(
      'Speech error: "${error.errorMsg}", permanent: ${error.permanent}',
    );
    if (!_cardActive || _activeAttemptId == null) {
      _log('Speech error ignored: no active attempt.');
      return;
    }
    if (_isLanguageUnavailableError(error) && !_forceDefaultLocale) {
      _forceDefaultLocale = true;
      _log('Speech language unavailable. Falling back to system default.');
      unawaited(_restartListeningAfterLocaleFallback());
      return;
    }
    final isAttemptError =
        _isSpeechTimeoutError(error) || _isNoMatchError(error);
    if (_isClientError(error)) {
      if (_suppressNextClientError) {
        _suppressNextClientError = false;
        return;
      }
      _consecutiveClientErrors += 1;
      final shouldPause =
          _consecutiveClientErrors >= _maxConsecutiveClientErrors;
      if (shouldPause) {
        emitEvent(const TaskError(
          'Speech recognition stopped. Tap Start to try again.',
        ));
        unawaited(_stopAttempt(stopTimer: true));
        return;
      }
      if (_activeAttemptId != null) {
        unawaited(
          _handleAttemptResult(recognizedText: ''),
        );
      }
      return;
    }
    _consecutiveClientErrors = 0;
    if (isAttemptError) {
      if (_cardActive) {
        _suppressNextClientError = true;
      }
      if (_activeAttemptId != null) {
        unawaited(
          _handleAttemptResult(recognizedText: ''),
        );
      }
      return;
    }

    emitEvent(TaskError(_friendlySpeechError(error)));
    unawaited(_stopAttempt(stopTimer: true));
  }

  void _onSpeechStatus(String status) {
    // Timer is managed independently of speech status.
  }

  Future<void> _restartListeningAfterLocaleFallback() async {
    if (!_cardActive) return;
    _suppressNextClientError = false;
    _activeAttemptId = null;
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    await Future.delayed(_listenRestartDelay);
    await _startListening();
  }

  String? _resolveLocaleId(LearningLanguage language) {
    if (_forceDefaultLocale) return null;
    final prefix = language.code.toLowerCase();
    for (final locale in _speechService.locales) {
      if (locale.localeId.toLowerCase().startsWith(prefix)) {
        return locale.localeId;
      }
    }
    return null;
  }

  stt.ListenMode _resolveListenMode() {
    if (_answerMatcher.expectedTokens.length <= 2) {
      return stt.ListenMode.search;
    }
    return stt.ListenMode.dictation;
  }

  Duration _remainingCardDuration() => _cardTimer.remaining();

  bool _isNoMatchError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase().trim();
    return code == 'error_no_match' || code.contains('no_match');
  }

  bool _isSpeechTimeoutError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase().trim();
    return code == 'error_speech_timeout' ||
        code == 'error_speach_timeout' ||
        code.contains('speech_timeout') ||
        code.contains('speach_timeout');
  }

  bool _isClientError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase().trim();
    return code == 'error_client' || code.contains('client');
  }

  bool _isLanguageUnavailableError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase().trim();
    return code == 'error_language_unavailable' ||
        code.contains('language_unavailable');
  }

  String _friendlySpeechError(SpeechRecognitionError error) {
    final message = error.errorMsg.trim();
    if (message.isEmpty) {
      return 'Speech recognition error.';
    }
    if (_isLanguageUnavailableError(error)) {
      return 'Selected language is not available on this device.';
    }
    if (_isSpeechTimeoutError(error)) {
      return 'No speech detected (timeout).';
    }
    if (_isNoMatchError(error)) {
      return 'Could not match speech.';
    }
    return 'Speech recognition error: $message';
  }

  void _log(String message) {
    if (!kDebugMode) return;
    final now = DateTime.now().toString();
    final time = now.substring(11, 23);
    debugPrint('[$time] $message');
  }
}
