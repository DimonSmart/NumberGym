import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../base_language_profile.dart';
import '../core/logging/app_logger.dart';
import '../exercise_models.dart';
import '../matcher/answer_matcher.dart';
import '../matcher/matcher_tokenizer.dart';
import '../task_runtime.dart';
import '../trainer_services.dart';
import '../trainer_state.dart';

class SpeakRuntime extends TaskRuntimeBase {
  SpeakRuntime({
    required ExerciseCard card,
    required BaseLanguageProfile profile,
    required MatcherTokenizer tokenizer,
    required SpeechServiceBase speechService,
    required SoundWaveServiceBase soundWaveService,
    required CardTimerBase cardTimer,
    required Duration cardDuration,
    required String? hintText,
    required void Function(bool ready, String? errorMessage) onSpeechReady,
  }) : _card = card,
       _profile = profile,
       _speechService = speechService,
       _soundWaveService = soundWaveService,
       _cardTimer = cardTimer,
       _cardDuration = cardDuration,
       _hintText = hintText,
       _onSpeechReady = onSpeechReady,
       _answerMatcher = AnswerMatcher(
         normalizer: profile.normalizer,
         tokenizer: tokenizer,
       ),
       super(
         SpeakState(
           exerciseId: card.id,
           family: card.family,
           displayText: card.displayText,
           promptText: card.promptText,
           acceptedAnswers: card.acceptedAnswers,
           celebrationText: card.celebrationText,
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

  final ExerciseCard _card;
  final BaseLanguageProfile _profile;
  final SpeechServiceBase _speechService;
  final SoundWaveServiceBase _soundWaveService;
  final CardTimerBase _cardTimer;
  final Duration _cardDuration;
  final String? _hintText;
  final void Function(bool ready, String? errorMessage) _onSpeechReady;
  final AnswerMatcher _answerMatcher;

  Future<void> _serialOperation = Future<void>.value();

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
  bool _paused = false;
  bool _timerHasStarted = false;
  bool _reportedInteraction = false;
  bool _deadlinePassed = false;
  int _emptyResultStreak = 0;
  bool _disposed = false;
  Timer? _listenStartTimer;
  Timer? _timeoutGraceTimer;

  @override
  Future<void> start() async {
    if (_disposed) {
      return;
    }
    _resetMatcher();
    _cardActive = true;
    _paused = false;
    _reportedInteraction = false;
    _suppressNextClientError = false;
    _consecutiveClientErrors = 0;
    _timerHasStarted = false;
    _deadlinePassed = false;
    _pendingListenAttemptId = null;
    _emptyResultStreak = 0;
    _listenStartTimer?.cancel();
    _timeoutGraceTimer?.cancel();

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
      return;
    }
    if (action is PauseTaskAction) {
      await _enqueue(_pauseForOverlay);
      return;
    }
    if (action is ResumeTaskAction) {
      await _enqueue(_resumeAfterOverlay);
      return;
    }
    if (action is RefreshTimerAction) {
      emitState(_buildState());
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
      prompt: _card.promptText,
      answers: _card.acceptedAnswers,
      promptAliases: _card.matcherConfig.promptAliases,
    );
    _lastHeardText = null;
    _lastHeardTokens = const <String>[];
    _lastMatchedIndices = const <int>[];
    _previewHeardText = null;
    _previewHeardTokens = const <String>[];
    _previewMatchedIndices = const <int>[];
    emitState(_buildState());
  }

  SpeakState _buildState() {
    return SpeakState(
      exerciseId: _card.id,
      family: _card.family,
      displayText: _card.displayText,
      promptText: _card.promptText,
      acceptedAnswers: _card.acceptedAnswers,
      celebrationText: _card.celebrationText,
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
    final remaining = _timerHasStarted ? _cardTimer.remaining() : _cardDuration;
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
      emitEvent(
        TaskError(
          result.errorMessage ??
              'Speech recognition is not available on this device.',
        ),
      );
      return false;
    }
    return true;
  }

  void _startCardTimer() {
    if (_timerHasStarted) {
      return;
    }
    _cardTimer.start(_cardDuration, () {
      unawaited(onTimerTimeout());
    });
    _timerHasStarted = true;
    emitState(_buildState());
  }

  Future<void> _startListening() async {
    if (!_cardActive || _paused || _deadlinePassed) {
      return;
    }
    final remaining = _remainingCardDuration();
    if (remaining < const Duration(milliseconds: 500)) {
      await _complete(TrainingOutcome.timeout);
      return;
    }

    final attemptId = ++_attemptCounter;
    _activeAttemptId = attemptId;
    _lastPartialResult = '';
    _clearPreview(emit: true);
    _suppressNextClientError = false;

    _pendingListenAttemptId = attemptId;
    _listenStartTimer?.cancel();

    try {
      _soundWaveService.reset();
      await _speechService.listen(
        onResult: (result) => _onSpeechResult(result, attemptId),
        onSoundLevelChange: (level) => _handleSoundLevel(level, attemptId),
        listenFor: remaining < _maxListenDuration ? remaining : _maxListenDuration,
        pauseFor: remaining < _maxListenDuration ? remaining : _maxListenDuration,
        localeId: _resolveLocaleId(),
        listenMode: _resolveListenMode(),
        partialResults: true,
      );
    } catch (error) {
      _pendingListenAttemptId = null;
      _markListeningStopped();
      emitEvent(const TaskError('Speech recognition failed to start.'));
      await _stopAttempt(stopTimer: true);
      return;
    }

    if (_speechService.isListening) {
      _markListeningStarted();
      return;
    }
    _listenStartTimer = Timer(_listenStartTimeout, () {
      if (!_cardActive || _pendingListenAttemptId != attemptId) {
        return;
      }
      if (_speechService.isListening) {
        _markListeningStarted();
        return;
      }
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
    if (_paused || _activeAttemptId != attemptId) {
      return;
    }
    _consecutiveClientErrors = 0;
    final recognizedWords = result.recognizedWords;
    if (recognizedWords.trim().isNotEmpty) {
      _reportUserInteraction();
    }
    if (!result.finalResult) {
      if (recognizedWords.trim().isNotEmpty &&
          recognizedWords != _lastPartialResult) {
        _lastPartialResult = recognizedWords;
        _updatePreviewFromPartial(recognizedWords);
        await _schedulePartialFastAcceptIfEligible(
          recognizedWords,
          attemptId,
        );
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
    if (_paused) {
      return;
    }
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();

    var resolvedText = recognizedText;
    if (resolvedText.trim().isEmpty && _lastPartialResult.isNotEmpty) {
      resolvedText = _lastPartialResult;
    }
    _lastPartialResult = '';
    if (resolvedText.trim().isNotEmpty) {
      _reportUserInteraction();
    }
    if (_activeAttemptId == null) {
      return;
    }
    _activeAttemptId = null;

    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _markListeningStopped();

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

    if (!_cardActive) {
      return;
    }
    if (_deadlinePassed) {
      return;
    }
    if (_remainingCardDuration() <= Duration.zero) {
      await _handleTimerTimeout();
      return;
    }
    await Future<void>.delayed(_restartDelayForEmptyResult());
    if (_deadlinePassed || !_cardActive) {
      return;
    }
    if (_speechService.isListening) {
      await _speechService.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await _startListening();
  }

  Future<void> _handleTimerTimeout() async {
    if (!_cardActive || _deadlinePassed || _paused) {
      return;
    }
    _deadlinePassed = true;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _clearPreview(emit: false);
    _timeoutGraceTimer?.cancel();
    _timeoutGraceTimer = Timer(_timeoutGrace, () {
      unawaited(_enqueue(_finalizeTimeoutGrace));
    });
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _markListeningStopped();
  }

  Future<void> _finalizeTimeoutGrace() async {
    if (!_cardActive || _answerMatcher.isComplete) {
      return;
    }
    await _complete(TrainingOutcome.timeout);
  }

  Future<void> _complete(TrainingOutcome outcome) async {
    if (!_cardActive) {
      return;
    }
    _cardActive = false;
    _activeAttemptId = null;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _timeoutGraceTimer?.cancel();
    _cardTimer.stop();
    _deadlinePassed = false;
    _emptyResultStreak = 0;
    _clearPreview(emit: false);
    _soundWaveService.stop();
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _isListening = false;
    appLogI(
      'task',
      'Answer: mode=${ExerciseMode.speak.name} id=${_card.id} '
          'heard="${_lastHeardText ?? '<empty>'}" outcome=${outcome.name}',
    );
    emitState(_buildState());
    emitEvent(TaskCompleted(outcome));
  }

  Future<void> _stopAttempt({bool stopTimer = false}) async {
    _activeAttemptId = null;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _timeoutGraceTimer?.cancel();
    _lastPartialResult = '';
    _clearPreview(emit: false);
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

  void _markListeningStarted() {
    if (!_cardActive || _paused) {
      return;
    }
    final attemptId = _pendingListenAttemptId ?? _activeAttemptId;
    if (attemptId == null || _activeAttemptId != attemptId) {
      return;
    }
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    final wasListening = _isListening;
    _isListening = true;
    _soundWaveService.start();
    if (!_timerHasStarted) {
      _startCardTimer();
    } else if (!wasListening) {
      emitState(_buildState());
    }
  }

  void _markListeningStopped() {
    if (_isListening) {
      _isListening = false;
      emitState(_buildState());
    }
    _soundWaveService.stop();
  }

  Future<void> _restartListeningAfterAttemptError() async {
    if (!_cardActive || _deadlinePassed) {
      return;
    }
    _activeAttemptId = null;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _lastPartialResult = '';
    _clearPreview(emit: false);
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _markListeningStopped();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!_cardActive || _deadlinePassed) {
      return;
    }
    await _startListening();
  }

  Future<void> _restartListeningAfterStartFailure(int attemptId) async {
    if (!_cardActive || _pendingListenAttemptId != attemptId || _deadlinePassed) {
      return;
    }
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    if (_activeAttemptId == attemptId) {
      _activeAttemptId = null;
    }
    _markListeningStopped();
    await Future<void>.delayed(_listenRestartDelay);
    if (_deadlinePassed || !_cardActive) {
      return;
    }
    await _startListening();
  }

  void _reportUserInteraction() {
    if (_reportedInteraction) {
      return;
    }
    _reportedInteraction = true;
    emitEvent(const TaskUserInteracted());
  }

  void _onSpeechError(SpeechRecognitionError error) {
    unawaited(_enqueue(() => _handleSpeechError(error)));
  }

  Future<void> _handleSpeechError(SpeechRecognitionError error) async {
    if (_paused || !_cardActive || _activeAttemptId == null || _deadlinePassed) {
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
      if (_consecutiveClientErrors >= _maxConsecutiveClientErrors) {
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
        await _handleAttemptResult(recognizedText: salvage);
        return;
      }
      await _restartListeningAfterAttemptError();
      return;
    }
    emitEvent(TaskError(_friendlySpeechError(error)));
    await _stopAttempt(stopTimer: true);
  }

  Future<void> _handleSpeechStatus(String status) async {
    if (_paused) {
      return;
    }
    if (status == stt.SpeechToText.listeningStatus) {
      _markListeningStarted();
      return;
    }
    if (status == stt.SpeechToText.notListeningStatus ||
        status == stt.SpeechToText.doneStatus) {
      _markListeningStopped();
    }
  }

  void _onSpeechStatus(String status) {
    unawaited(_enqueue(() => _handleSpeechStatus(status)));
  }

  String? _resolveLocaleId() {
    final preferred = _profile.preferredSpeechLocaleId;
    if (preferred != null) {
      final normalizedPreferred = _normalizeLocaleId(preferred);
      for (final locale in _speechService.locales) {
        if (_normalizeLocaleId(locale.localeId) == normalizedPreferred) {
          return locale.localeId;
        }
      }
    }
    final prefix = _profile.code.toLowerCase();
    for (final locale in _speechService.locales) {
      final normalized = _normalizeLocaleId(locale.localeId);
      if (normalized == prefix || normalized.startsWith('${prefix}_')) {
        return locale.localeId;
      }
    }
    return null;
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
    return _timerHasStarted ? _cardTimer.remaining() : _cardDuration;
  }

  bool _isPartialFastAcceptEligible() {
    return _card.acceptedAnswers.length <= 4;
  }

  Future<void> _schedulePartialFastAcceptIfEligible(
    String recognizedText,
    int attemptId,
  ) async {
    if (!_isPartialFastAcceptEligible()) {
      return;
    }
    final candidate = recognizedText.trim();
    if (candidate.isEmpty || !_answerMatcher.isAcceptedAnswer(candidate)) {
      return;
    }
    if (_activeAttemptId != attemptId) {
      return;
    }
    await _handleAttemptResult(recognizedText: candidate);
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

  String _friendlySpeechError(SpeechRecognitionError error) {
    final message = error.errorMsg.trim();
    if (message.isEmpty) {
      return 'Speech recognition error.';
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
    if (_disposed) {
      return Future<void>.value();
    }
    final next = _serialOperation.then((_) async {
      if (_disposed) {
        return;
      }
      await action();
    });
    _serialOperation = next.catchError((_) {});
    return next;
  }

  void _updatePreviewFromPartial(String recognizedText) {
    final preview = _answerMatcher.previewRecognition(
      recognizedText.replaceAll(',', ''),
    );
    _previewHeardText = preview.normalizedText.isEmpty
        ? null
        : preview.normalizedText;
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

  void _handleSoundLevel(double level, int attemptId) {
    if (_paused) {
      return;
    }
    _soundWaveService.onSoundLevel(level);
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

  Future<void> _pauseForOverlay() async {
    if (_paused || !_cardActive) {
      return;
    }
    _paused = true;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _cardTimer.pause();
    _clearPreview(emit: false);
    _soundWaveService.stop();
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _markListeningStopped();
    emitState(_buildState());
  }

  Future<void> _resumeAfterOverlay() async {
    if (!_paused || !_cardActive) {
      return;
    }
    _paused = false;
    if (_timerHasStarted) {
      _cardTimer.resume();
    }
    emitState(_buildState());
    if (_deadlinePassed || _answerMatcher.isComplete) {
      return;
    }
    if (_remainingCardDuration() <= Duration.zero) {
      await _handleTimerTimeout();
      return;
    }
    await _startListening();
  }
}
