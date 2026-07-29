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

enum _SpeechResultSource {
  partialCompletion,
  partialAcceptedAnswer,
  finalResult,
  clientError,
  errorSalvage,
}

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
           isListeningPending: false,
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
  bool _isListeningPending = false;
  bool _paused = false;
  bool _timerHasStarted = false;
  bool _reportedInteraction = false;
  bool _deadlinePassed = false;
  int _emptyResultStreak = 0;
  bool _speechCancelInFlight = false;
  bool _disposed = false;
  DateTime? _listenRequestedAt;
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
    _isListeningPending = false;
    _listenRequestedAt = null;
    _emptyResultStreak = 0;
    _speechCancelInFlight = false;
    _listenStartTimer?.cancel();
    _timeoutGraceTimer?.cancel();
    _logSpeech(
      'start cardActive=$_cardActive prompt="${_card.promptText}" '
      'answers=${_card.acceptedAnswers.length} duration=${_formatDuration(_cardDuration)}',
    );

    final ready = await _initSpeech();
    if (_disposed || !_cardActive || !ready) {
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
    _cardActive = false;
    _listenStartTimer?.cancel();
    _timeoutGraceTimer?.cancel();
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
      isListeningPending: _isListeningPending,
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
    _logSpeech('initSpeech start');
    final result = await _speechService.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    if (_disposed || !_cardActive) return false;
    _speechReady = result.ready;
    _onSpeechReady(result.ready, result.errorMessage);
    emitState(_buildState());
    _logSpeech(
      'initSpeech result ready=${result.ready} error="${result.errorMessage ?? ''}" '
      'locales=${_speechService.locales.length}',
    );
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
      _logSpeech(
        'startListening skipped cardActive=$_cardActive paused=$_paused '
        'deadlinePassed=$_deadlinePassed',
      );
      return;
    }
    final remaining = _remainingCardDuration();
    if (remaining < const Duration(milliseconds: 500)) {
      _logSpeech(
        'startListening remaining too low remaining=${_formatDuration(remaining)}',
      );
      await _complete(TrainingOutcome.timeout);
      return;
    }

    final attemptId = ++_attemptCounter;
    _activeAttemptId = attemptId;
    _lastPartialResult = '';
    _clearPreview(emit: true);
    _suppressNextClientError = false;

    _pendingListenAttemptId = attemptId;
    _isListeningPending = true;
    _listenRequestedAt = DateTime.now();
    _listenStartTimer?.cancel();
    emitState(_buildState());

    final listenDuration = remaining < _maxListenDuration
        ? remaining
        : _maxListenDuration;
    final localeId = _resolveLocaleId();
    final listenMode = _resolveListenMode();
    _logSpeech(
      'listen start attempt=$attemptId remaining=${_formatDuration(remaining)} '
      'listenFor=${_formatDuration(listenDuration)} pauseFor=${_formatDuration(listenDuration)} '
      'locale="${localeId ?? ''}" mode=${listenMode.name} '
      'requestedAt="${_listenRequestedAt!.toIso8601String()}" '
      'expected=${_formatStrings(_answerMatcher.expectedTokens)} '
      'matched=${_formatBools(_answerMatcher.matchedTokens)}',
    );

    try {
      _soundWaveService.reset();
      await _speechService.listen(
        onResult: (result) => _onSpeechResult(result, attemptId),
        onSoundLevelChange: (level) => _handleSoundLevel(level, attemptId),
        listenFor: listenDuration,
        pauseFor: listenDuration,
        localeId: localeId,
        listenMode: listenMode,
        partialResults: true,
      );
    } catch (error) {
      _logSpeech('listen start failed attempt=$attemptId error="$error"');
      _pendingListenAttemptId = null;
      _markListeningStopped();
      emitEvent(const TaskError('Speech recognition failed to start.'));
      await _stopAttempt(stopTimer: true);
      return;
    }

    if (_speechService.isListening) {
      _logSpeech('listen active immediately attempt=$attemptId');
      _markListeningStarted(source: 'service_is_listening');
      return;
    }
    _logSpeech(
      'listen pending start attempt=$attemptId timeout=${_formatDuration(_listenStartTimeout)}',
    );
    _listenStartTimer = Timer(_listenStartTimeout, () {
      if (!_cardActive || _pendingListenAttemptId != attemptId) {
        _logSpeech(
          'listen start timer ignored attempt=$attemptId cardActive=$_cardActive '
          'pending=$_pendingListenAttemptId',
        );
        return;
      }
      if (_speechService.isListening) {
        _logSpeech(
          'listen became active before start timeout attempt=$attemptId',
        );
        _markListeningStarted(source: 'start_timeout_service_is_listening');
        return;
      }
      _logSpeech('listen start timeout attempt=$attemptId');
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
      _logSpeech(
        'result ignored attempt=$attemptId active=$_activeAttemptId paused=$_paused '
        'final=${result.finalResult} raw="${result.recognizedWords}"',
      );
      return;
    }
    _consecutiveClientErrors = 0;
    final recognizedWords = result.recognizedWords;
    _logSpeech(
      'result attempt=$attemptId final=${result.finalResult} '
      'raw="$recognizedWords" trimmed="${recognizedWords.trim()}" '
      'lastPartial="$_lastPartialResult" remaining=${_formatDuration(_remainingCardDuration())} '
      'deadlinePassed=$_deadlinePassed serviceListening=${_speechService.isListening}',
    );
    if (recognizedWords.trim().isNotEmpty) {
      _reportUserInteraction();
    }
    if (!result.finalResult) {
      if (recognizedWords.trim().isNotEmpty &&
          recognizedWords != _lastPartialResult) {
        _lastPartialResult = recognizedWords;
        _updatePreviewFromPartial(recognizedWords);
        final wouldComplete = _answerMatcher.wouldCompleteWith(
          recognizedWords.replaceAll(',', ''),
        );
        _logSpeech(
          'partial evaluated attempt=$attemptId wouldComplete=$wouldComplete '
          'previewText="${_previewHeardText ?? ''}" '
          'previewTokens=${_formatStrings(_previewHeardTokens)} '
          'previewMatched=${_formatInts(_previewMatchedIndices)} '
          'matched=${_formatBools(_answerMatcher.matchedTokens)}',
        );
        if (wouldComplete) {
          _logSpeech('partial accepted attempt=$attemptId reason=complete');
          await _handleAttemptResult(
            recognizedText: recognizedWords,
            source: _SpeechResultSource.partialCompletion,
          );
          return;
        }
        await _schedulePartialFastAcceptIfEligible(recognizedWords, attemptId);
      } else if (recognizedWords.trim().isEmpty) {
        _logSpeech('partial empty attempt=$attemptId');
        _clearPreview(emit: true);
      } else {
        _logSpeech('partial duplicate attempt=$attemptId');
      }
      return;
    }
    final resolvedWords = recognizedWords.trim().isEmpty
        ? _lastPartialResult
        : recognizedWords;
    _logSpeech(
      'final resolved attempt=$attemptId resolved="$resolvedWords" '
      'usedLastPartial=${recognizedWords.trim().isEmpty && _lastPartialResult.isNotEmpty}',
    );
    _lastPartialResult = '';
    await _handleAttemptResult(
      recognizedText: resolvedWords,
      source: _SpeechResultSource.finalResult,
    );
  }

  Future<void> _handleAttemptResult({
    required String recognizedText,
    required _SpeechResultSource source,
  }) async {
    final resultHandlingStartedAt = DateTime.now();
    if (_paused) {
      _logSpeech('attempt result ignored while paused raw="$recognizedText"');
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
      _logSpeech(
        'attempt result ignored without active attempt raw="$recognizedText"',
      );
      return;
    }
    final attemptId = _activeAttemptId!;
    _logSpeech(
      'attempt result apply attempt=$attemptId source=${source.name} '
      'raw="$recognizedText" '
      'resolved="$resolvedText" deadlinePassed=$_deadlinePassed '
      'remaining=${_formatDuration(_remainingCardDuration())}',
    );
    _activeAttemptId = null;

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
    _logSpeech(
      'attempt match attempt=$attemptId normalized="${matchResult.normalizedText}" '
      'accepted=${matchResult.acceptedAnswer} '
      'recognizedTokens=${_formatStrings(matchResult.recognizedTokens)} '
      'matchedNow=${_formatInts(matchResult.matchedSegmentIndices)} '
      'matched=${_formatBools(_answerMatcher.matchedTokens)} '
      'complete=${_answerMatcher.isComplete}',
    );

    if (_answerMatcher.isComplete) {
      _logSpeech(
        'attempt complete correct attempt=$attemptId source=${source.name} '
        'matchLatency=${_formatDuration(DateTime.now().difference(resultHandlingStartedAt))}',
      );
      _cancelListeningAfterAcceptedAnswer(attemptId);
      _markListeningStopped();
      await _complete(TrainingOutcome.correct, stopSpeech: false);
      return;
    }

    if (_speechService.isListening) {
      final stopStartedAt = DateTime.now();
      await _speechService.stop();
      _logSpeech(
        'attempt stop finished attempt=$attemptId '
        'duration=${_formatDuration(DateTime.now().difference(stopStartedAt))}',
      );
    }
    _markListeningStopped();

    if (resolvedText.trim().isEmpty) {
      _emptyResultStreak += 1;
    } else {
      _emptyResultStreak = 0;
    }

    if (!_cardActive) {
      _logSpeech('attempt not complete but card inactive attempt=$attemptId');
      return;
    }
    if (_deadlinePassed) {
      _logSpeech('attempt not complete after deadline attempt=$attemptId');
      return;
    }
    if (_remainingCardDuration() <= Duration.zero) {
      _logSpeech('attempt not complete remaining zero attempt=$attemptId');
      await _handleTimerTimeout();
      return;
    }
    final restartDelay = _restartDelayForEmptyResult();
    _logSpeech(
      'attempt restart scheduled attempt=$attemptId delay=${_formatDuration(restartDelay)} '
      'emptyStreak=$_emptyResultStreak',
    );
    await Future<void>.delayed(restartDelay);
    if (_deadlinePassed || !_cardActive) {
      _logSpeech(
        'attempt restart cancelled attempt=$attemptId cardActive=$_cardActive '
        'deadlinePassed=$_deadlinePassed',
      );
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
      _logSpeech(
        'timeout ignored cardActive=$_cardActive deadlinePassed=$_deadlinePassed paused=$_paused',
      );
      return;
    }
    _logSpeech(
      'timeout reached active=$_activeAttemptId pending=$_pendingListenAttemptId '
      'lastPartial="$_lastPartialResult" preview="${_previewHeardText ?? ''}" '
      'matched=${_formatBools(_answerMatcher.matchedTokens)} '
      'complete=${_answerMatcher.isComplete}',
    );
    _deadlinePassed = true;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _clearPreview(emit: false);
    _timeoutGraceTimer?.cancel();
    _logSpeech(
      'timeout grace scheduled duration=${_formatDuration(_timeoutGrace)}',
    );
    _timeoutGraceTimer = Timer(_timeoutGrace, () {
      unawaited(_enqueue(_finalizeTimeoutGrace));
    });
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    _markListeningStopped();
  }

  Future<void> _finalizeTimeoutGrace() async {
    _logSpeech(
      'timeout grace finalize cardActive=$_cardActive complete=${_answerMatcher.isComplete} '
      'lastHeard="${_lastHeardText ?? ''}" matched=${_formatBools(_answerMatcher.matchedTokens)}',
    );
    if (!_cardActive || _answerMatcher.isComplete) {
      return;
    }
    await _complete(TrainingOutcome.timeout);
  }

  void _cancelListeningAfterAcceptedAnswer(int attemptId) {
    if (!_speechService.isListening) {
      _logSpeech(
        'accepted cleanup skipped attempt=$attemptId reason=not_listening',
      );
      return;
    }
    final startedAt = DateTime.now();
    _speechCancelInFlight = true;
    _logSpeech(
      'accepted cleanup cancel start attempt=$attemptId '
      'startedAt="${startedAt.toIso8601String()}"',
    );
    unawaited(
      _speechService
          .cancel()
          .then((_) {
            _logSpeech(
              'accepted cleanup cancel finished attempt=$attemptId '
              'duration=${_formatDuration(DateTime.now().difference(startedAt))}',
            );
          })
          .catchError((Object error, StackTrace stackTrace) {
            appLogW(
              'speech',
              'speak id=${_card.id} accepted cleanup cancel failed',
              error: error,
              st: stackTrace,
            );
          })
          .whenComplete(() {
            _speechCancelInFlight = false;
          }),
    );
  }

  Future<void> _complete(
    TrainingOutcome outcome, {
    bool stopSpeech = true,
  }) async {
    if (!_cardActive) {
      return;
    }
    final completionStartedAt = DateTime.now();
    _cardActive = false;
    _activeAttemptId = null;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _timeoutGraceTimer?.cancel();
    _cardTimer.stop();
    _deadlinePassed = false;
    _emptyResultStreak = 0;
    _isListeningPending = false;
    _listenRequestedAt = null;
    _clearPreview(emit: false);
    _soundWaveService.stop();
    if (stopSpeech && _speechService.isListening) {
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
    _logSpeech(
      'completion emitted outcome=${outcome.name} stopSpeech=$stopSpeech '
      'duration=${_formatDuration(DateTime.now().difference(completionStartedAt))}',
    );
  }

  Future<void> _stopAttempt({bool stopTimer = false}) async {
    _activeAttemptId = null;
    _pendingListenAttemptId = null;
    _listenStartTimer?.cancel();
    _timeoutGraceTimer?.cancel();
    _isListeningPending = false;
    _listenRequestedAt = null;
    _lastPartialResult = '';
    _clearPreview(emit: false);
    _isListening = false;
    _soundWaveService.stop();
    if (stopTimer) {
      _cardTimer.stop();
    }
    if (_speechService.isListening && !_speechCancelInFlight) {
      await _speechService.stop();
    } else if (_speechCancelInFlight) {
      _logSpeech(
        'stopAttempt skipped service stop because cancel is in flight',
      );
    }
    emitState(_buildState());
  }

  void _markListeningStarted({required String source}) {
    if (!_cardActive || _paused) {
      _logSpeech(
        'markListeningStarted skipped cardActive=$_cardActive paused=$_paused',
      );
      return;
    }
    final attemptId = _pendingListenAttemptId ?? _activeAttemptId;
    if (attemptId == null || _activeAttemptId != attemptId) {
      _logSpeech(
        'markListeningStarted ignored attempt=$attemptId active=$_activeAttemptId',
      );
      return;
    }
    if (_isListening && !_isListeningPending) {
      _logSpeech('listening start duplicate attempt=$attemptId source=$source');
      return;
    }
    final activatedAt = DateTime.now();
    final requestedAt = _listenRequestedAt;
    final activationDelay = requestedAt == null
        ? null
        : activatedAt.difference(requestedAt);
    _pendingListenAttemptId = null;
    _isListeningPending = false;
    _listenRequestedAt = null;
    _listenStartTimer?.cancel();
    final wasListening = _isListening;
    _isListening = true;
    _soundWaveService.start();
    _logSpeech(
      'listening started attempt=$attemptId source=$source '
      'wasListening=$wasListening activatedAt="${activatedAt.toIso8601String()}" '
      'activationDelay=${activationDelay == null ? "unknown" : _formatDuration(activationDelay)}',
    );
    if (!_timerHasStarted) {
      _startCardTimer();
    } else if (!wasListening) {
      emitState(_buildState());
    }
  }

  void _markListeningStopped() {
    final wasPending = _isListeningPending;
    _isListeningPending = false;
    _listenRequestedAt = null;
    if (_isListening) {
      _isListening = false;
      _logSpeech('listening stopped');
      emitState(_buildState());
    } else if (wasPending) {
      _logSpeech('listening start stopped while pending');
      emitState(_buildState());
    }
    _soundWaveService.stop();
  }

  Future<void> _restartListeningAfterAttemptError() async {
    if (!_cardActive || _deadlinePassed) {
      _logSpeech(
        'restart after attempt error skipped cardActive=$_cardActive deadlinePassed=$_deadlinePassed',
      );
      return;
    }
    _logSpeech(
      'restart after attempt error active=$_activeAttemptId lastPartial="$_lastPartialResult"',
    );
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
    if (!_cardActive ||
        _pendingListenAttemptId != attemptId ||
        _deadlinePassed) {
      _logSpeech(
        'restart after start failure skipped attempt=$attemptId cardActive=$_cardActive '
        'pending=$_pendingListenAttemptId deadlinePassed=$_deadlinePassed',
      );
      return;
    }
    _logSpeech('restart after start failure attempt=$attemptId');
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
    if (_paused ||
        !_cardActive ||
        _activeAttemptId == null ||
        _deadlinePassed) {
      _logSpeech(
        'error ignored code="${error.errorMsg}" permanent=${error.permanent} '
        'paused=$_paused cardActive=$_cardActive active=$_activeAttemptId '
        'deadlinePassed=$_deadlinePassed',
      );
      return;
    }
    _logSpeech(
      'error code="${error.errorMsg}" permanent=${error.permanent} '
      'active=$_activeAttemptId lastPartial="$_lastPartialResult" '
      'clientStreak=$_consecutiveClientErrors',
    );
    final isAttemptError =
        _isSpeechTimeoutError(error) || _isNoMatchError(error);
    if (_isClientError(error)) {
      if (_suppressNextClientError) {
        _logSpeech('client error suppressed code="${error.errorMsg}"');
        _suppressNextClientError = false;
        return;
      }
      _consecutiveClientErrors += 1;
      if (_consecutiveClientErrors >= _maxConsecutiveClientErrors) {
        _logSpeech(
          'client error limit reached count=$_consecutiveClientErrors',
        );
        emitEvent(
          const TaskError(
            'Speech recognition stopped. Tap Try again to resume.',
          ),
        );
        await _stopAttempt(stopTimer: true);
        return;
      }
      if (_activeAttemptId != null) {
        await _handleAttemptResult(
          recognizedText: '',
          source: _SpeechResultSource.clientError,
        );
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
        _logSpeech('attempt error salvaging partial="$salvage"');
        await _handleAttemptResult(
          recognizedText: salvage,
          source: _SpeechResultSource.errorSalvage,
        );
        return;
      }
      _logSpeech('attempt error without salvage, restarting');
      await _restartListeningAfterAttemptError();
      return;
    }
    emitEvent(TaskError(_friendlySpeechError(error)));
    await _stopAttempt(stopTimer: true);
  }

  Future<void> _handleSpeechStatus(String status) async {
    if (_paused) {
      _logSpeech('status ignored while paused status="$status"');
      return;
    }
    _logSpeech(
      'status="$status" active=$_activeAttemptId pending=$_pendingListenAttemptId '
      'serviceListening=${_speechService.isListening}',
    );
    if (status == stt.SpeechToText.listeningStatus) {
      _markListeningStarted(source: 'status');
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
      _logSpeech(
        'partial fast accept skipped attempt=$attemptId reason=too_many_answers '
        'answers=${_card.acceptedAnswers.length}',
      );
      return;
    }
    final candidate = recognizedText.trim();
    if (candidate.isEmpty || !_answerMatcher.isAcceptedAnswer(candidate)) {
      _logSpeech(
        'partial fast accept skipped attempt=$attemptId reason=not_accepted '
        'candidate="$candidate"',
      );
      return;
    }
    if (_activeAttemptId != attemptId) {
      _logSpeech(
        'partial fast accept skipped attempt=$attemptId reason=inactive active=$_activeAttemptId',
      );
      return;
    }
    _logSpeech('partial fast accept attempt=$attemptId candidate="$candidate"');
    await _handleAttemptResult(
      recognizedText: candidate,
      source: _SpeechResultSource.partialAcceptedAnswer,
    );
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

  void _logSpeech(String message) {
    appLogD('speech', 'speak id=${_card.id} $message');
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMilliseconds}ms';
  }

  String _formatStrings(List<String> values) {
    return '[${values.map((value) => '"$value"').join(',')}]';
  }

  String _formatInts(List<int> values) {
    return '[${values.join(',')}]';
  }

  String _formatBools(List<bool> values) {
    return '[${values.map((value) => value ? '1' : '0').join(',')}]';
  }
}
