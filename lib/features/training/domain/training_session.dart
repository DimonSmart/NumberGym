import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/card_progress.dart';
import '../data/number_card.dart';
import '../data/number_cards.dart';
import 'learning_language.dart';
import 'repositories.dart';
import 'services/answer_matcher.dart';
import 'services/card_timer.dart';
import 'services/keep_awake_service.dart';
import 'services/sound_wave_service.dart';
import 'services/speech_service.dart';
import 'training_state.dart';

class TrainingSession {
  TrainingSession({
    required SettingsRepositoryBase settingsRepository,
    required ProgressRepositoryBase progressRepository,
    stt.SpeechToText? speech,
    SpeechServiceBase? speechService,
    SoundWaveServiceBase? soundWaveService,
    AnswerMatcher? answerMatcher,
    CardTimerBase? cardTimer,
    KeepAwakeServiceBase? keepAwakeService,
    void Function()? onStateChanged,
  })  : _settingsRepository = settingsRepository,
        _progressRepository = progressRepository,
        _speechService = speechService ?? SpeechService(speech: speech),
        _soundWaveService = soundWaveService ?? SoundWaveService(),
        _answerMatcher = answerMatcher ?? AnswerMatcher(),
        _cardTimer = cardTimer ?? CardTimer(),
        _keepAwakeService = keepAwakeService ?? KeepAwakeService(),
        _onStateChanged = onStateChanged ?? _noop {
    final cards = buildNumberCards();
    _cardsById = {for (final card in cards) card.id: card};
    _cardIds = _cardsById.keys.toList()..sort();
    _syncState();
  }

  static void _noop() {}

  final Random _random = Random();
  final SpeechServiceBase _speechService;
  final SoundWaveServiceBase _soundWaveService;
  final AnswerMatcher _answerMatcher;
  final CardTimerBase _cardTimer;
  final KeepAwakeServiceBase _keepAwakeService;
  final ProgressRepositoryBase _progressRepository;
  final SettingsRepositoryBase _settingsRepository;
  final void Function() _onStateChanged;

  late final Map<int, SpeakNumberTask> _cardsById;
  late final List<int> _cardIds;

  Map<int, CardProgress> _progressById = {};
  List<int> _pool = [];

  TrainerStatus _status = TrainerStatus.idle;
  bool _speechReady = false;
  String? _errorMessage;

  int _attemptCounter = 0;
  int? _activeAttemptId;
  int? _currentCardId;
  int? _currentPoolIndex;
  SpeakNumberTask? _currentCard;
  int _consecutiveSilentCards = 0;
  int _consecutiveClientErrors = 0;
  int _consecutiveCorrectAnswers = 0;
  bool _cardActive = false;
  bool _heardSpeechThisCard = false;

  String _lastPartialResult = '';
  static const Duration _listenRestartDelay = Duration(milliseconds: 500);
  static const int _maxConsecutiveClientErrors = 3;

  TrainingFeedback? _feedback;
  Timer? _feedbackTimer;
  bool _forceDefaultLocale = false;
  bool _suppressNextClientError = false;

  bool _disposed = false;

  TrainingState _state = TrainingState.initial();
  TrainingState get state => _state;

  Stream<List<double>> get soundStream => _soundWaveService.stream;

  int get totalCards => _cardsById.length;
  int get learnedCount =>
      _progressById.values.where((progress) => progress.learned).length;
  int get remainingCount => totalCards - learnedCount;
  bool get hasRemainingCards => _pool.isNotEmpty;

  Future<void> initialize() async {
    await _loadProgress();
    _syncState();
  }

  Future<void> retryInitSpeech() async {
    await _initSpeech();
    _syncState();
  }

  Future<void> startTraining() async {
    if (_status == TrainerStatus.running) return;
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        _syncState();
        return;
      }
    }

    if (_pool.isEmpty) {
      _status = TrainerStatus.finished;
      unawaited(_setKeepAwake(false));
      _syncState();
      return;
    }

    _errorMessage = null;
    _status = TrainerStatus.running;
    _consecutiveSilentCards = 0;
    _consecutiveClientErrors = 0;
    _consecutiveCorrectAnswers = 0;
    _forceDefaultLocale = false;
    _suppressNextClientError = false;
    _syncState();
    unawaited(_setKeepAwake(true));
    await _startNextCard();
  }

  Future<void> stopTraining() async {
    _feedbackTimer?.cancel();
    await _stopAttempt();
    _soundWaveService.reset();
    _forceDefaultLocale = false;
    _suppressNextClientError = false;
    _status = TrainerStatus.idle;
    _errorMessage = null;
    _currentCard = null;
    _currentCardId = null;
    _currentPoolIndex = null;
    _consecutiveSilentCards = 0;
    _consecutiveClientErrors = 0;
    _consecutiveCorrectAnswers = 0;
    _heardSpeechThisCard = false;
    _answerMatcher.clear();
    _feedback = null;
    _lastPartialResult = '';
    _syncState();
    unawaited(_setKeepAwake(false));
  }

  Future<void> pauseForOverlay() async {
    await _stopAttempt();
    _status = TrainerStatus.idle;
    await _setKeepAwake(false);
    _syncState();
  }

  Future<void> restoreAfterOverlay() async {
    await _loadProgress();
    _currentCard = null;
    _currentCardId = null;
    _currentPoolIndex = null;
    _consecutiveSilentCards = 0;
    _heardSpeechThisCard = false;
    _forceDefaultLocale = false;
    _answerMatcher.clear();
    _status = TrainerStatus.idle;
    await _setKeepAwake(false);
    _syncState();
  }

  void _syncState() {
    if (_disposed) return;
    _state = TrainingState(
      status: _status,
      speechReady: _speechReady,
      errorMessage: _errorMessage,
      feedback: _feedback,
      currentCard: _currentCard,
      hintText: _resolveHintText(),
      expectedTokens: List.unmodifiable(_answerMatcher.expectedTokens),
      matchedTokens: List.unmodifiable(_answerMatcher.matchedTokens),
      cardDuration: _cardTimer.duration,
      isTimerRunning: _cardTimer.isRunning,
    );
    _onStateChanged();
  }

  void _log(String message) {
    final now = DateTime.now().toString();
    final time = now.substring(11, 23);
    debugPrint('[$time] $message');
  }

  void dispose() {
    _disposed = true;
    _feedbackTimer?.cancel();
    _soundWaveService.dispose();
    _cardTimer.dispose();
    _speechService.dispose();
    _keepAwakeService.dispose();
  }

  Future<void> _loadProgress() async {
    if (_cardIds.isEmpty) {
      _progressById = {};
      _pool = [];
      return;
    }
    final progress = await _progressRepository.loadAll(_cardIds);
    _progressById = {
      for (final id in _cardIds) id: progress[id] ?? CardProgress.empty,
    };
    _pool = [
      for (final id in _cardIds)
        if (!(_progressById[id]?.learned ?? false)) id,
    ]..shuffle(_random);
  }

  Future<void> _initSpeech() async {
    _errorMessage = null;
    final result = await _speechService.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    if (!result.ready) {
      _speechReady = false;
      _errorMessage = result.errorMessage;
      return;
    }
    _speechReady = true;
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _log(
      'Speech error: "${error.errorMsg}", permanent: ${error.permanent}',
    );
    if (_status != TrainerStatus.running ||
        !_cardActive ||
        _activeAttemptId == null) {
      _log('Speech error ignored: no active attempt.');
      return;
    }
    if (_isLanguageUnavailableError(error) && !_forceDefaultLocale) {
      _forceDefaultLocale = true;
      _log(
        'Speech language unavailable. Falling back to system default locale.',
      );
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
        _errorMessage = 'Speech recognition stopped. Tap Start to try again.';
        if (_status == TrainerStatus.running) {
          _status = TrainerStatus.paused;
        }
        _syncState();
        unawaited(_setKeepAwake(false));
        unawaited(_stopAttempt());
        return;
      }
      if (_status == TrainerStatus.running && _activeAttemptId != null) {
        unawaited(
          _handleAttemptResult(
            recognizedText: '',
          ),
        );
      }
      return;
    }
    _consecutiveClientErrors = 0;
    if (isAttemptError) {
      if (_status == TrainerStatus.running && _cardActive) {
        _suppressNextClientError = true;
      }
      if (_status == TrainerStatus.running && _activeAttemptId != null) {
        unawaited(
          _handleAttemptResult(
            recognizedText: '',
          ),
        );
      }
      return;
    }

    _errorMessage = _friendlySpeechError(error);
    if (_status == TrainerStatus.running) {
      _status = TrainerStatus.paused;
    }
    _syncState();
    unawaited(_setKeepAwake(false));
    unawaited(_stopAttempt());
  }

  void _onSpeechStatus(String status) {
    // Timer is managed independently of speech status.
  }

  Future<void> _restartListeningAfterLocaleFallback() async {
    if (_status != TrainerStatus.running || !_cardActive) return;
    _suppressNextClientError = false;
    _activeAttemptId = null;
    if (_speechService.isListening) {
      await _speechService.stop();
    }
    await Future.delayed(_listenRestartDelay);
    await _startListening();
  }

  LearningLanguage _currentLanguage() {
    return _settingsRepository.readLearningLanguage();
  }

  String? _resolveLocaleId(LearningLanguage language) {
    if (_forceDefaultLocale) return null;
    final prefix = language.localePrefix.toLowerCase();
    for (final locale in _speechService.locales) {
      if (locale.localeId.toLowerCase().startsWith(prefix)) {
        return locale.localeId;
      }
    }
    return null;
  }

  // TODO: Tune duration per prompt if needed.
  Duration _resolveCardDuration(String prompt) {
    final seconds = _settingsRepository.readAnswerDurationSeconds();
    return Duration(seconds: seconds);
  }

  String? _resolveHintText() {
    if (!_cardActive || _currentCard == null) return null;
    final maxStreak = _settingsRepository.readHintStreakCount();
    if (maxStreak <= 0 || _consecutiveCorrectAnswers >= maxStreak) {
      return null;
    }
    final language = _currentLanguage();
    final answers = _currentCard?.answersFor(language) ?? const <String>[];
    if (answers.isEmpty) return null;

    final prompt = (_currentCard?.prompt ?? '').trim().toLowerCase();
    for (final answer in answers) {
      final trimmed = answer.trim();
      if (trimmed.isEmpty) continue;
      if (prompt.isNotEmpty && trimmed.toLowerCase() == prompt) {
        continue;
      }
      return trimmed;
    }

    final fallback = answers.first.trim();
    return fallback.isEmpty ? null : fallback;
  }

  stt.ListenMode _resolveListenMode() {
    if (_answerMatcher.expectedTokens.length <= 2) {
      return stt.ListenMode.search;
    }
    return stt.ListenMode.dictation;
  }

  void _resetCardProgress(SpeakNumberTask? card) {
    final prompt = card?.prompt ?? '';
    final language = _currentLanguage();
    final answers = card?.answersFor(language) ?? const <String>[];
    _answerMatcher.reset(prompt: prompt, answers: answers);
    if (prompt.isNotEmpty) {
      _log(
        'Speech expected: "$prompt" (lang: ${language.code}, '
        'answers: ${answers.join(", ")})',
      );
    }
  }

  bool get _isCardComplete => _answerMatcher.isComplete;

  Duration _remainingCardDuration() => _cardTimer.remaining();

  Future<void> _startNextCard() async {
    if (_status != TrainerStatus.running) return;
    if (_pool.isEmpty) {
      _status = TrainerStatus.finished;
      unawaited(_setKeepAwake(false));
      _syncState();
      return;
    }

    final poolIndex = _random.nextInt(_pool.length);
    _currentPoolIndex = poolIndex;
    _currentCardId = _pool[poolIndex];
    _currentCard = _cardsById[_currentCardId];
    _cardActive = true;
    _heardSpeechThisCard = false;
    _resetCardProgress(_currentCard);
    _soundWaveService.reset();
    _suppressNextClientError = false;

    final prompt = _currentCard?.prompt ?? '';
    final duration = _resolveCardDuration(prompt);

    _cardTimer.start(duration, _onTimerTimeout);
    _syncState();
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_currentCardId == null ||
        _status != TrainerStatus.running ||
        !_cardActive) {
      return;
    }
    final remaining = _remainingCardDuration();
    if (remaining < const Duration(milliseconds: 500)) {
      unawaited(_completeCard(isCorrect: false, timeout: true));
      return;
    }
    final attemptId = ++_attemptCounter;
    _activeAttemptId = attemptId;
    _lastPartialResult = '';
    _suppressNextClientError = false;

    final language = _currentLanguage();
    final localeId = _resolveLocaleId(language);
    final listenMode = _resolveListenMode();
    _log(
      'Speech listen: remaining=${remaining.inMilliseconds}ms '
      'locale=${localeId ?? "system"} mode=$listenMode',
    );
    _soundWaveService.start();

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
      _errorMessage = 'Speech recognition failed to start.';
      _status = TrainerStatus.paused;
      _syncState();
      await _stopAttempt();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result, int attemptId) {
    if (_activeAttemptId != attemptId) return;
    _consecutiveClientErrors = 0;
    final recognizedWords = result.recognizedWords;
    if (recognizedWords.trim().isNotEmpty) {
      _heardSpeechThisCard = true;
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

  void _onTimerTimeout() {
    if (_status != TrainerStatus.running || !_cardActive) return;
    unawaited(_completeCard(isCorrect: false, timeout: true));
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
      _heardSpeechThisCard = true;
    }
    final attemptId = _activeAttemptId;
    if (attemptId == null) return;
    _activeAttemptId = null;
    if (_speechService.isListening) {
      await _speechService.stop();
    }

    final didMatch = _answerMatcher.applyRecognition(resolvedText);
    if (didMatch) {
      _syncState();
    }

    if (_isCardComplete) {
      await _completeCard(isCorrect: true, timeout: false);
      return;
    }

    if (_status != TrainerStatus.running || !_cardActive) return;
    if (_remainingCardDuration() <= Duration.zero) {
      await _completeCard(isCorrect: false, timeout: true);
      return;
    }
    await Future.delayed(_listenRestartDelay);
    await _startListening();
  }

  Future<void> _completeCard({
    required bool isCorrect,
    required bool timeout,
  }) async {
    if (!_cardActive || _currentCardId == null) return;
    _cardActive = false;
    _activeAttemptId = null;
    _cardTimer.stop();

    _soundWaveService.stop();
    await _speechService.stop();

    if (isCorrect) {
      _consecutiveCorrectAnswers += 1;
    } else {
      _consecutiveCorrectAnswers = 0;
    }

    await _updateProgress(isCorrect: isCorrect);
    _showFeedback(isCorrect, timeout: timeout);

    if (_status == TrainerStatus.running) {
      if (_heardSpeechThisCard) {
        _consecutiveSilentCards = 0;
      } else {
        _consecutiveSilentCards += 1;
      }
      if (_consecutiveSilentCards >= 3) {
        await _pauseTraining();
        return;
      }
    }

    await _startNextCard();
  }

  Future<void> _updateProgress({required bool isCorrect}) async {
    final cardId = _currentCardId;
    if (cardId == null) return;
    final progress = _progressById[cardId] ?? CardProgress.empty;
    final attempts = List<bool>.from(progress.lastAttempts)..add(isCorrect);
    if (attempts.length > 10) {
      attempts.removeRange(0, attempts.length - 10);
    }
    final learned = attempts.length == 10 && attempts.every((value) => value);
    final updated = progress.copyWith(
      learned: learned,
      lastAttempts: attempts,
      totalAttempts: progress.totalAttempts + 1,
      totalCorrect: progress.totalCorrect + (isCorrect ? 1 : 0),
    );
    _progressById[cardId] = updated;
    await _progressRepository.save(cardId, updated);
    if (learned) {
      _removeFromPool();
    }
    _syncState();
  }

  void _removeFromPool() {
    final index = _currentPoolIndex;
    if (index == null || index >= _pool.length) return;
    final lastIndex = _pool.length - 1;
    _pool[index] = _pool[lastIndex];
    _pool.removeLast();
    _currentPoolIndex = null;
    if (_pool.isEmpty) {
      _status = TrainerStatus.finished;
      unawaited(_setKeepAwake(false));
    }
  }

  void _showFeedback(
    bool isCorrect, {
    required bool timeout,
  }) {
    _feedbackTimer?.cancel();
    final text = isCorrect
        ? 'Correct'
        : timeout
            ? 'Timeout'
            : 'Wrong';
    final type = isCorrect
        ? TrainingFeedbackType.correct
        : timeout
            ? TrainingFeedbackType.timeout
            : TrainingFeedbackType.wrong;
    _feedback = TrainingFeedback(type: type, text: text);
    _syncState();

    _feedbackTimer = Timer(const Duration(seconds: 3), () {
      _feedback = null;
      _syncState();
    });
  }

  Future<void> _pauseTraining() async {
    await _stopAttempt();
    _status = TrainerStatus.paused;
    _syncState();
    unawaited(_setKeepAwake(false));
  }

  Future<void> _stopAttempt() async {
    _activeAttemptId = null;
    _cardActive = false;
    _soundWaveService.stop();
    _cardTimer.stop();

    if (_speechService.isListening) {
      await _speechService.stop();
    }
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

  Future<void> _setKeepAwake(bool enabled) async {
    await _keepAwakeService.setEnabled(enabled);
  }
}
