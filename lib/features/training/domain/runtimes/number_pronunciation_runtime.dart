import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/logging/app_logger.dart';
import '../learning_language.dart';
import '../services/answer_matcher.dart';
import '../services/card_timer.dart';
import '../services/sound_wave_service.dart';
import '../services/speech_service.dart';
import '../task_runtime.dart';
import '../task_state.dart';
import '../training_task.dart';
import '../training_outcome.dart';
import '../../languages/registry.dart';

class NumberPronunciationRuntime extends TaskRuntimeBase {
  NumberPronunciationRuntime({
    required PronunciationTaskData task,
    required SpeechServiceBase speechService,
    required SoundWaveServiceBase soundWaveService,
    required CardTimerBase cardTimer,
    required Duration cardDuration,
    required String? hintText,
    required void Function(bool ready, String? errorMessage) onSpeechReady,
  }) : _task = task,
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
           lastHeardText: null,
           lastHeardTokens: const <String>[],
           lastMatchedIndices: const <int>[],
           previewHeardText: null,
           previewHeardTokens: const <String>[],
           previewMatchedIndices: const <int>[],
           hintText: hintText,
           isListening: false,
           speechReady: false,
         ),
       );

  static const Duration _listenRestartDelay = Duration(milliseconds: 500);
  static const Duration _listenStartTimeout = Duration(milliseconds: 1500);
  static const Duration _timeoutGrace = Duration(milliseconds: 500);
  static const Duration _maxListenDuration = Duration(seconds: 10);
  static const int _maxConsecutiveClientErrors = 3;

  final PronunciationTaskData _task;
  final SpeechServiceBase _speechService;
  final SoundWaveServiceBase _soundWaveService;
  final CardTimerBase _cardTimer;
  final Duration _cardDuration;
  final String? _hintText;
  final void Function(bool ready, String? errorMessage) _onSpeechReady;
  final AnswerMatcher _answerMatcher = AnswerMatcher();

  Future<void> _serialOperation = Future.value();

  int _attemptCounter = 0;
  int? _activeAttemptId;
  int? _pendingListenAttemptId;
  String _lastPartialResult = '';
  String? _lastHeardText;
  List<String> _lastHeardTokens = const <String>[];
  List<int> _lastMatchedIndices = const <int>[];
  String? _previewHeardText;
  List<String> _previewHeardTokens = const <String>[];
  List<int> _previewMatchedIndices = const <int>[];
  bool _suppressNextClientError = false;
  int _consecutiveClientErrors = 0;
  bool _speechReady = false;
  bool _cardActive = false;
  bool _isListening = false;
  bool _timerHasStarted = false;
  bool _reportedInteraction = false;
  bool _deadlinePassed = false;
  bool _currentAttemptHadSpeech = false;
  int _emptyResultStreak = 0;
  int _soundLevelSampleCount = 0;
  int _partialResultCount = 0;
  bool _disposed = false;
  Timer? _listenStartTimer;
  Timer? _timeoutGraceTimer;

  @override
  Future<void> start() async {
    if (_disposed) return;
    _resetMatcher();
    _cardActive = true;
    _reportedInteraction = false;
    _suppressNextClientError = false;
    _consecutiveClientErrors = 0;
    _timerHasStarted = false;
    _deadlinePassed = false;
    _pendingListenAttemptId = null;
    _currentAttemptHadSpeech = false;
    _emptyResultStreak = 0;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;
    _timeoutGraceTimer?.cancel();
    _timeoutGraceTimer = null;

    final ready = await _initSpeech();
    if (!ready) {
      return;
    }

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
    await _enqueue(_handleTimerTimeout);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _stopAttempt(stopTimer: true);
    await super.dispose();
  }

  void _resetMatcher() {
    _answerMatcher.reset(
      prompt: _task.prompt,
      answers: _task.answers,
      language: _task.language,
    );
    _lastHeardText = null;
    _lastHeardTokens = const <String>[];
    _lastMatchedIndices = const <int>[];
    _previewHeardText = null;
    _previewHeardTokens = const <String>[];
    _previewMatchedIndices = const <int>[];
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
      lastHeardText: _lastHeardText,
      lastHeardTokens: List<String>.unmodifiable(_lastHeardTokens),
      lastMatchedIndices: List<int>.unmodifiable(_lastMatchedIndices),
      previewHeardText: _previewHeardText,
      previewHeardTokens: List<String>.unmodifiable(_previewHeardTokens),
      previewMatchedIndices: List<int>.unmodifiable(_previewMatchedIndices),
      hintText: _hintText,
      isListening: _isListening,
      speechReady: _speechReady,
    );
  }

  TimerState _timerSnapshot() {
    final remaining = _timerHasStarted
        ? (_cardTimer.isRunning ? _cardTimer.remaining() : Duration.zero)
        : _cardDuration;
    return TimerState(
      isRunning: _cardTimer.isRunning,
      duration: _cardDuration,
      remaining: remaining,
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
      final message =
          result.errorMessage ??
          'Speech recognition is not available on this device.';
      emitEvent(TaskError(message));
      return false;
    }
    return true;
  }

  void _startCardTimer() {
    if (_timerHasStarted) return;
    _cardTimer.start(_cardDuration, _onTimerTimeout);
    _timerHasStarted = true;
    _log('Speech timer started: duration=${_cardDuration.inMilliseconds}ms');
    emitState(_buildState());
  }

  Future<void> _startListening() async {
    if (!_cardActive) return;
    if (_deadlinePassed) return;
    final remaining = _remainingCardDuration();
    if (remaining < const Duration(milliseconds: 500)) {
      await _complete(TrainingOutcome.timeout);
      return;
    }

    final attemptId = ++_attemptCounter;
    _activeAttemptId = attemptId;
    _lastPartialResult = '';
    _clearPreview(emit: true);
    _currentAttemptHadSpeech = false;
    _suppressNextClientError = false;
    _soundLevelSampleCount = 0;
    _partialResultCount = 0;

    final localeId = _resolveLocaleId(_task.language);
    final listenMode = _resolveListenMode();
    _log(
      'Speech listen: remaining=${remaining.inMilliseconds}ms '
      'locale=${localeId ?? "system"} mode=$listenMode attempt=$attemptId',
    );

    _pendingListenAttemptId = attemptId;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;

    final listenFor = remaining < _maxListenDuration
        ? remaining
        : _maxListenDuration;
    final pauseFor = listenFor;
    _log(
      'Speech listen config: listenFor=${listenFor.inMilliseconds}ms '
      'pauseFor=${pauseFor.inMilliseconds}ms',
    );

    try {
      _soundWaveService.reset();
      await _speechService.listen(
        onResult: (result) => _onSpeechResult(result, attemptId),
        onSoundLevelChange: (level) =>
            _handleSoundLevel(level: level, attemptId: attemptId),
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
        listenMode: listenMode,
        partialResults: true,
      );
    } catch (error) {
      _log('Speech listen failed to start: $error');
      _pendingListenAttemptId = null;
      _markListeningStopped(source: 'listen-error');
      emitEvent(const TaskError('Speech recognition failed to start.'));
      await _stopAttempt(stopTimer: true);
      return;
    }

    final listening = _speechService.isListening;
    if (listening) {
      _markListeningStarted(source: 'listen-call');
      return;
    }

    _log('Speech listen awaiting start: isListening=false');
    _listenStartTimer?.cancel();
    _listenStartTimer = Timer(_listenStartTimeout, () {
      if (!_cardActive || _pendingListenAttemptId != attemptId) return;
      final started = _speechService.isListening;
      if (started) {
        _markListeningStarted(source: 'listen-timeout-check');
        return;
      }
      _log(
        'Speech listen did not start within '
        '${_listenStartTimeout.inMilliseconds}ms.',
      );
      unawaited(_enqueue(() => _restartListeningAfterStartFailure(attemptId)));
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result, int attemptId) {
    unawaited(_enqueue(() => _handleSpeechResult(result, attemptId)));
  }

  Future<void> _handleSpeechResult(
    SpeechRecognitionResult result,
    int attemptId,
  ) async {
    if (_activeAttemptId != attemptId) {
      _log(
        'Late result ignored for attempt=$attemptId: '
        '"${result.recognizedWords}" final=${result.finalResult}',
      );
      return;
    }
    _consecutiveClientErrors = 0;
    final recognizedWords = result.recognizedWords;
    _log(
      'Speech result: final=${result.finalResult} '
      'length=${recognizedWords.length} attempt=$attemptId',
    );
    if (recognizedWords.trim().isNotEmpty) {
      _currentAttemptHadSpeech = true;
      _reportUserInteraction();
    }
    if (!result.finalResult) {
      _partialResultCount += 1;
      if (recognizedWords.trim().isNotEmpty &&
          recognizedWords != _lastPartialResult) {
        _lastPartialResult = recognizedWords;
        _log('Speech partial: "$recognizedWords"');
        _updatePreviewFromPartial(recognizedWords);
      } else if (recognizedWords.trim().isEmpty) {
        _clearPreview(emit: true);
      }
      return;
    }
    final resolvedWords = recognizedWords.trim().isEmpty
        ? _lastPartialResult
        : recognizedWords;
    _lastPartialResult = '';
    await _handleAttemptResult(recognizedText: resolvedWords);
  }

  Future<void> _handleAttemptResult({required String recognizedText}) async {
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;

    var resolvedText = recognizedText;
    if (resolvedText.trim().isEmpty && _lastPartialResult.isNotEmpty) {
      resolvedText = _lastPartialResult;
    }
    _lastPartialResult = '';
    _log('Speech recognized: "$resolvedText"');
    if (resolvedText.trim().isNotEmpty) {
      _currentAttemptHadSpeech = true;
      _reportUserInteraction();
    }
    final attemptId = _activeAttemptId;
    if (attemptId == null) return;
    _activeAttemptId = null;

    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _markListeningStopped(source: 'result');

    _clearPreview(emit: false);
    final matchResult = _answerMatcher.applyRecognition(
      resolvedText.replaceAll(',', ''),
    );
    _lastHeardText = matchResult.normalizedText.isEmpty
        ? null
        : matchResult.normalizedText;
    _lastHeardTokens = matchResult.recognizedTokens;
    _lastMatchedIndices = matchResult.matchedSegmentIndices;
    emitState(_buildState());

    if (_answerMatcher.isComplete) {
      await _complete(TrainingOutcome.correct);
      return;
    }

    if (resolvedText.trim().isEmpty) {
      _emptyResultStreak += 1;
    } else {
      _emptyResultStreak = 0;
    }

    if (!_cardActive) return;
    if (_deadlinePassed) {
      _log('Deadline passed; waiting for grace finalization.');
      return;
    }
    if (_remainingCardDuration() <= Duration.zero) {
      await _handleTimerTimeout();
      return;
    }
    await Future.delayed(_restartDelayForEmptyResult());

    if (_deadlinePassed || !_cardActive) return;
    if (_speechService.isListening) {
      _log('Speech still listening after delay. Forcing stop before restart.');
      await _speechService.stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    await _startListening();
  }

  void _onTimerTimeout() {
    unawaited(onTimerTimeout());
  }

  Future<void> _handleTimerTimeout() async {
    if (!_cardActive || _deadlinePassed) return;
    _deadlinePassed = true;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;
    _clearPreview(emit: false);
    _timeoutGraceTimer?.cancel();
    _timeoutGraceTimer = Timer(_timeoutGrace, () {
      unawaited(_enqueue(_finalizeTimeoutGrace));
    });
    _log('Speech timer deadline reached. Waiting for grace window.');
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _markListeningStopped(source: 'timeout');
  }

  Future<void> _finalizeTimeoutGrace() async {
    if (!_cardActive) return;
    if (_answerMatcher.isComplete) return;
    await _complete(TrainingOutcome.timeout);
  }

  Future<void> _complete(TrainingOutcome outcome) async {
    if (!_cardActive) return;
    _cardActive = false;
    _activeAttemptId = null;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;
    _timeoutGraceTimer?.cancel();
    _timeoutGraceTimer = null;
    _cardTimer.stop();
    _deadlinePassed = false;
    _currentAttemptHadSpeech = false;
    _emptyResultStreak = 0;
    _clearPreview(emit: false);
    _soundWaveService.stop();
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _isListening = false;
    final heard = _lastHeardText?.trim();
    appLogI(
      'task',
      'Answer: kind=numberPronunciation id=${_task.id} '
      'heard="${heard == null || heard.isEmpty ? '<empty>' : heard}" '
      'outcome=${outcome.name}',
    );
    _log('Speech attempt completed: outcome=$outcome');
    emitState(_buildState());
    emitEvent(TaskCompleted(outcome));
  }

  Future<void> _stopAttempt({bool stopTimer = false}) async {
    _activeAttemptId = null;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;
    _timeoutGraceTimer?.cancel();
    _timeoutGraceTimer = null;
    _lastPartialResult = '';
    _currentAttemptHadSpeech = false;
    _clearPreview(emit: false);
    _isListening = false;
    _soundWaveService.stop();
    if (stopTimer) {
      _cardTimer.stop();
    }
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _log('Speech attempt stopped (stopTimer=$stopTimer)');
    emitState(_buildState());
  }

  void _markListeningStarted({required String source}) {
    if (!_cardActive) return;
    final attemptId = _pendingListenAttemptId ?? _activeAttemptId;
    if (attemptId == null) {
      _log('Speech listen started ignored: no active attempt.');
      return;
    }
    if (_activeAttemptId != attemptId) {
      return;
    }
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;

    final wasListening = _isListening;
    _isListening = true;
    _soundWaveService.start();

    if (!_timerHasStarted) {
      _startCardTimer();
    } else if (!wasListening) {
      emitState(_buildState());
    }

    _log(
      'Speech listen started ($source): isListening=${_speechService.isListening}',
    );
  }

  void _markListeningStopped({required String source}) {
    if (_isListening) {
      _isListening = false;
      emitState(_buildState());
    }
    _soundWaveService.stop();
    _log('Speech listen stopped ($source)');
  }

  Future<void> _restartListeningAfterAttemptError() async {
    if (!_cardActive || _deadlinePassed) return;
    _activeAttemptId = null;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;
    _lastPartialResult = '';
    _currentAttemptHadSpeech = false;
    _clearPreview(emit: false);
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _markListeningStopped(source: 'attempt-error');
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_cardActive || _deadlinePassed) return;
    await _startListening();
  }

  Future<void> _restartListeningAfterStartFailure(int attemptId) async {
    if (!_cardActive || _pendingListenAttemptId != attemptId) return;
    if (_deadlinePassed) return;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _listenStartTimer = null;
    if (_activeAttemptId == attemptId) {
      _activeAttemptId = null;
    }
    _markListeningStopped(source: 'listen-start-failed');
    await Future.delayed(_listenRestartDelay);
    if (_deadlinePassed || !_cardActive) return;
    await _startListening();
  }

  void _reportUserInteraction() {
    if (_reportedInteraction) return;
    _reportedInteraction = true;
    emitEvent(const TaskUserInteracted());
  }

  void _onSpeechError(SpeechRecognitionError error) {
    unawaited(_enqueue(() => _handleSpeechError(error)));
  }

  Future<void> _handleSpeechError(SpeechRecognitionError error) async {
    _log('Speech error: "${error.errorMsg}", permanent: ${error.permanent}');
    if (!_cardActive || _activeAttemptId == null) {
      _log('Speech error ignored: no active attempt.');
      return;
    }
    if (_deadlinePassed) {
      _log('Speech error ignored: deadline already passed.');
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
        emitEvent(
          const TaskError(
            'Speech recognition stopped. Tap Try again to resume.',
          ),
        );
        await _stopAttempt(stopTimer: true);
        return;
      }
      if (_activeAttemptId != null) {
        await _handleAttemptResult(recognizedText: '');
      }
      return;
    }
    _consecutiveClientErrors = 0;
    if (isAttemptError) {
      if (_cardActive) {
        _suppressNextClientError = true;
      }
      final salvage = _lastPartialResult.trim();
      if (salvage.isNotEmpty) {
        _log('Speech salvage from partial due to error: "$salvage"');
        await _handleAttemptResult(recognizedText: salvage);
        return;
      }
      _log('Speech attempt failed: ${error.errorMsg}. Restarting listen.');
      await _restartListeningAfterAttemptError();
      return;
    }

    emitEvent(TaskError(_friendlySpeechError(error)));
    await _stopAttempt(stopTimer: true);
  }

  Future<void> _handleSpeechStatus(String status) async {
    _log(
      'Speech status: "$status" '
      'attempt=$_activeAttemptId '
      'isListening=${_speechService.isListening} '
      'hadSpeech=$_currentAttemptHadSpeech '
      'partials=$_partialResultCount '
      'soundSamples=$_soundLevelSampleCount',
    );
    if (status == stt.SpeechToText.listeningStatus) {
      _markListeningStarted(source: 'status');
      return;
    }
    if (status == stt.SpeechToText.notListeningStatus ||
        status == stt.SpeechToText.doneStatus) {
      _markListeningStopped(source: 'status');
    }
  }

  void _onSpeechStatus(String status) {
    unawaited(_enqueue(() => _handleSpeechStatus(status)));
  }

  String? _resolveLocaleId(LearningLanguage language) {
    final preferred = _preferredLocaleId(language);
    if (preferred != null) {
      final preferredNormalized = _normalizeLocaleId(preferred);
      for (final locale in _speechService.locales) {
        if (_normalizeLocaleId(locale.localeId) == preferredNormalized) {
          return locale.localeId;
        }
      }
    }

    final prefix = language.code.toLowerCase();
    for (final locale in _speechService.locales) {
      final normalized = _normalizeLocaleId(locale.localeId);
      if (normalized == prefix || normalized.startsWith('${prefix}_')) {
        return locale.localeId;
      }
    }
    return null;
  }

  String? _preferredLocaleId(LearningLanguage language) {
    return LanguageRegistry.of(language).preferredSpeechLocaleId;
  }

  String _normalizeLocaleId(String localeId) {
    return localeId.toLowerCase().replaceAll('-', '_');
  }

  stt.ListenMode _resolveListenMode() {
    if (_answerMatcher.expectedTokens.length <= 2) {
      return stt.ListenMode.search;
    }
    return stt.ListenMode.dictation;
  }

  Duration _remainingCardDuration() {
    if (!_timerHasStarted) return _cardDuration;
    return _cardTimer.remaining();
  }

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

  Future<void> _enqueue(Future<void> Function() action) {
    if (_disposed) return Future.value();
    final next = _serialOperation.then((_) async {
      if (_disposed) return;
      await action();
    });
    _serialOperation = next.catchError((error, stack) {
      _log('Speech runtime error: $error');
    });
    return next;
  }

  void _log(String message) {
    appLogD('speech', message);
  }

  void _updatePreviewFromPartial(String recognizedText) {
    final preview = _answerMatcher.previewRecognition(
      recognizedText.replaceAll(',', ''),
    );
    final nextText = preview.normalizedText.isEmpty
        ? null
        : preview.normalizedText;
    if (_previewHeardText == nextText &&
        _previewMatchedIndices.length == preview.matchedSegmentIndices.length &&
        _previewHeardTokens.length == preview.recognizedTokens.length) {
      var sameIndices = true;
      for (var i = 0; i < _previewMatchedIndices.length; i += 1) {
        if (_previewMatchedIndices[i] != preview.matchedSegmentIndices[i]) {
          sameIndices = false;
          break;
        }
      }
      var sameTokens = true;
      for (var i = 0; i < _previewHeardTokens.length; i += 1) {
        if (_previewHeardTokens[i] != preview.recognizedTokens[i]) {
          sameTokens = false;
          break;
        }
      }
      if (sameIndices && sameTokens) {
        return;
      }
    }
    _previewHeardText = nextText;
    _previewHeardTokens = preview.recognizedTokens;
    _previewMatchedIndices = preview.matchedSegmentIndices;
    emitState(_buildState());
  }

  void _clearPreview({bool emit = false}) {
    if (_previewHeardText == null &&
        _previewHeardTokens.isEmpty &&
        _previewMatchedIndices.isEmpty) {
      return;
    }
    _previewHeardText = null;
    _previewHeardTokens = const <String>[];
    _previewMatchedIndices = const <int>[];
    if (emit) {
      emitState(_buildState());
    }
  }

  void _handleSoundLevel({required double level, required int attemptId}) {
    _soundWaveService.onSoundLevel(level);
    if (_activeAttemptId != attemptId) return;
    _soundLevelSampleCount += 1;
    if (level.abs() > 0.5) {
      _currentAttemptHadSpeech = true;
    }
  }

  Duration _restartDelayForEmptyResult() {
    if (_emptyResultStreak <= 0) {
      return _listenRestartDelay;
    }
    const maxDelayMs = 1600;
    final delayMs =
        _listenRestartDelay.inMilliseconds + (_emptyResultStreak * 300);
    return Duration(milliseconds: delayMs > maxDelayMs ? maxDelayMs : delayMs);
  }
}
