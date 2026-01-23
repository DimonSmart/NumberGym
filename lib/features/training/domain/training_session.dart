import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/card_progress.dart';
import '../data/number_cards.dart';
import '../data/phrase_templates.dart';
import 'language_router.dart';
import 'learning_language.dart';
import 'pronunciation_models.dart';
import 'repositories.dart';
import 'services/answer_matcher.dart';
import 'services/audio_recorder_service.dart';
import 'services/azure_speech_service.dart';
import 'services/card_timer.dart';
import 'services/internet_checker.dart';
import 'services/keep_awake_service.dart';
import 'services/sound_wave_service.dart';
import 'services/speech_service.dart';
import 'tasks/number_pronunciation_task.dart';
import 'tasks/number_to_word_task.dart';
import 'tasks/phrase_pronunciation_task.dart';
import 'tasks/word_to_number_task.dart';
import 'training_state.dart';
import 'training_task.dart';

enum TrainingOutcome { success, fail, timeout, ignore }

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
    AudioRecorderServiceBase? audioRecorder,
    AzureSpeechService? azureSpeechService,
    PhraseTemplates? phraseTemplates,
    void Function()? onStateChanged,
  })  : _settingsRepository = settingsRepository,
        _progressRepository = progressRepository,
        _speechService = speechService ?? SpeechService(speech: speech),
        _soundWaveService = soundWaveService ?? SoundWaveService(),
        _answerMatcher = answerMatcher ?? AnswerMatcher(),
        _cardTimer = cardTimer ?? CardTimer(),
        _keepAwakeService = keepAwakeService ?? KeepAwakeService(),
        _audioRecorder = audioRecorder ?? AudioRecorderService(),
        _azureSpeechService = azureSpeechService ?? AzureSpeechService(),
        _onStateChanged = onStateChanged ?? _noop {
    final resolvedTemplates = phraseTemplates ?? PhraseTemplates(Random());
    _languageRouter = LanguageRouter(
      settingsRepository: _settingsRepository,
      phraseTemplates: resolvedTemplates,
    );
    _refreshCardsIfNeeded();
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    _syncState();
  }

  static void _noop() {}

  final Random _random = Random();
  final SpeechServiceBase _speechService;
  final SoundWaveServiceBase _soundWaveService;
  final AnswerMatcher _answerMatcher;
  final CardTimerBase _cardTimer;
  final KeepAwakeServiceBase _keepAwakeService;
  final AudioRecorderServiceBase _audioRecorder;
  final ProgressRepositoryBase _progressRepository;
  final SettingsRepositoryBase _settingsRepository;
  final AzureSpeechService _azureSpeechService;
  late final LanguageRouter _languageRouter;
  final void Function() _onStateChanged;

  Map<int, NumberPronunciationTask> _cardsById = {};
  List<int> _cardIds = [];
  LearningLanguage? _cardsLanguage;

  Map<int, CardProgress> _progressById = {};
  List<int> _pool = [];

  TrainingTask? _currentTask;
  PhrasePronunciationTask? _currentPhraseTask;
  PronunciationAnalysisResult? _pronunciationResult;
  bool _premiumPronunciationEnabled = false;
  TrainingTaskKind? _debugForcedTaskKind;
  bool _isRecording = false;
  File? _recordingFile;
  StreamSubscription<double>? _recordingLevelSubscription;
  bool _awaitingPronunciationReview = false;

  TrainerStatus _status = TrainerStatus.idle;
  bool _speechReady = false;
  String? _errorMessage;

  int _attemptCounter = 0;
  int? _activeAttemptId;
  int? _currentCardId;
  int? _currentPoolIndex;
  NumberPronunciationTask? _currentCard;
  int _consecutiveSilentCards = 0;
  int _consecutiveClientErrors = 0;
  int _consecutiveCorrectAnswers = 0;
  bool _cardActive = false;
  bool _heardSpeechThisCard = false;

  String _lastPartialResult = '';
  static const Duration _listenRestartDelay = Duration(milliseconds: 500);
  static const int _maxConsecutiveClientErrors = 3;
  static const int _numberPronunciationWeight = 70;
  static const int _numberToWordWeight = 15;
  static const int _wordToNumberWeight = 15;
  static const int _phrasePronunciationWeight = 5;
  static const Duration _internetCheckCache = Duration(seconds: 10);

  TrainingFeedback? _feedback;
  Timer? _feedbackTimer;
  bool _forceDefaultLocale = false;
  bool _suppressNextClientError = false;

  bool _disposed = false;
  bool _hasInternet = true;
  DateTime? _lastInternetCheck;

  TrainingState _state = TrainingState.initial();
  TrainingState get state => _state;

  Stream<List<double>> get soundStream => _soundWaveService.stream;

  int get totalCards => _cardsById.length;
  int get learnedCount =>
      _progressById.values.where((progress) => progress.learned).length;
  int get remainingCount => totalCards - learnedCount;
  bool get hasRemainingCards => _pool.isNotEmpty;

  bool get premiumPronunciationEnabled => _premiumPronunciationEnabled;
  Future<void> setPremiumPronunciationEnabled(bool enabled) async {
    _premiumPronunciationEnabled = enabled;
    await _settingsRepository.setPremiumPronunciationEnabled(enabled);
    _syncState();
  }

  PhrasePronunciationTask? get currentPhraseTask => _currentPhraseTask;
  PronunciationAnalysisResult? get pronunciationResult => _pronunciationResult;

  Future<void> initialize() async {
    await _loadProgress();
    _syncState();
  }

  Future<void> retryInitSpeech() async {
    await _initSpeech();
    _syncState();
  }

  Future<void> startTraining() async {
    if (_status == TrainerStatus.running ||
        _status == TrainerStatus.waitingRecording) {
      return;
    }

    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    if (_cardsLanguage != _currentLanguage()) {
      await _loadProgress();
    }
    await _refreshInternetStatus(force: true);
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
    _currentTask = null;
    _currentCardId = null;
    _currentPoolIndex = null;
    _currentPhraseTask = null;
    _pronunciationResult = null;
    _recordingFile = null;
    _isRecording = false;
    _awaitingPronunciationReview = false;
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
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
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    _currentCard = null;
    _currentTask = null;
    _currentCardId = null;
    _currentPoolIndex = null;
    _currentPhraseTask = null;
    _pronunciationResult = null;
    _recordingFile = null;
    _isRecording = false;
    _awaitingPronunciationReview = false;
    _consecutiveSilentCards = 0;
    _heardSpeechThisCard = false;
    _forceDefaultLocale = false;
    _answerMatcher.clear();
    _status = TrainerStatus.idle;
    await _setKeepAwake(false);
    _syncState();
  }

  Future<PronunciationAnalysisResult> analyzePronunciationRecording(
    File audioFile,
  ) async {
    if (_currentPhraseTask == null) {
      throw StateError('No active pronunciation task');
    }
    _heardSpeechThisCard = true;
    final expectedText = _currentPhraseTask!.text;
    final exists = await audioFile.exists();
    final size = exists ? await audioFile.length() : null;
    _log(
      'Pronunciation analyze: expected="${_trimForLog(expectedText)}" '
      'file="${audioFile.path}" exists=$exists size=${size ?? "n/a"}',
    );
    try {
      final language = _currentLanguage();
      final languageCode = language.locale;

      final result = await _azureSpeechService.analyzePronunciation(
        audioFile: audioFile,
        expectedText: expectedText,
        language: languageCode,
      );
      _pronunciationResult = result;
      _syncState();
      _log(_formatPronunciationResult(result));
      return result;
    } on AzureSpeechFailure catch (error) {
      final body = error.body == null ? '' : _trimForLog(error.body!);
      _log(
        'Pronunciation analyze failed: ${error.message} '
        '(code: ${error.statusCode ?? "n/a"}) body="$body"',
      );
      rethrow;
    } catch (error) {
      _log('Pronunciation analyze failed: $error');
      rethrow;
    }
  }

  Future<void> completeCurrentTaskWithOutcome(TrainingOutcome outcome) async {
    if (!_cardActive || _currentTask == null) return;
    await _completeCard(outcome: outcome);
  }

  Future<void> startPronunciationRecording() async {
    if (_currentTask is! PhrasePronunciationTask) return;
    if (_status != TrainerStatus.waitingRecording) return;
    if (_isRecording) return;
    _recordingFile = null;
    _pronunciationResult = null;
    _awaitingPronunciationReview = false;
    try {
      await _audioRecorder.start();
      _isRecording = true;
      await _startRecordingSoundWave();
      _log('Pronunciation recording started.');
    } catch (error) {
      _errorMessage = 'Cannot start recording: $error';
      _log('Pronunciation recording failed to start: $error');
    }
    _syncState();
  }

  Future<File?> stopPronunciationRecording() async {
    if (_currentTask is! PhrasePronunciationTask) return _recordingFile;
    if (!_isRecording) return _recordingFile;
    try {
      final file = await _audioRecorder.stop();
      _isRecording = false;
      await _stopRecordingSoundWave();
      _recordingFile = file;
      if (file == null) {
        _log('Pronunciation recording stopped: file missing.');
      } else {
        final size = await file.length();
        _log(
          'Pronunciation recording stopped: file="${file.path}" size=$size',
        );
      }
      _syncState();
      return file;
    } catch (error) {
      _isRecording = false;
      await _stopRecordingSoundWave();
      _errorMessage = 'Recording failed: $error';
      _log('Pronunciation recording failed to stop: $error');
      _syncState();
      return null;
    }
  }

  Future<void> cancelPronunciationRecording() async {
    if (_isRecording) {
      await _audioRecorder.cancel();
      _isRecording = false;
    }
    await _stopRecordingSoundWave();
    _recordingFile = null;
    _pronunciationResult = null;
    _awaitingPronunciationReview = false;
    _syncState();
  }

  Future<PronunciationAnalysisResult> sendPronunciationRecording({
    File? file,
  }) async {
    final resolved = file ?? _recordingFile;
    if (resolved == null) {
      throw StateError('No recording to send');
    }
    _log('Pronunciation send: starting.');
    final result = await analyzePronunciationRecording(resolved);
    _awaitingPronunciationReview = true;
    _syncState();
    _log('Pronunciation send: completed, awaiting review.');
    return result;
  }

  Future<void> completePronunciationReview() async {
    if (!_awaitingPronunciationReview) return;
    if (_currentTask?.kind != TrainingTaskKind.phrasePronunciation) return;
    _awaitingPronunciationReview = false;
    // Pronunciation tasks do not affect progress; advance with ignore.
    await _completeCard(outcome: TrainingOutcome.ignore);
    _log('Pronunciation review: completed, advancing to next task.');
  }

  Future<void> answerNumberToWord(String selectedOption) async {
    if (_currentTask is! NumberToWordTask) return;
    if (!_cardActive) return;
    final task = _currentTask as NumberToWordTask;
    final normalized = selectedOption.trim().toLowerCase();
    final correct = task.correctOption.trim().toLowerCase();
    _heardSpeechThisCard = true;
    await _completeCard(
      outcome: normalized == correct
          ? TrainingOutcome.success
          : TrainingOutcome.fail,
    );
  }

  Future<void> answerWordToNumber(String selectedOption) async {
    if (_currentTask is! WordToNumberTask) return;
    if (!_cardActive) return;
    final task = _currentTask as WordToNumberTask;
    final normalized = selectedOption.trim().toLowerCase();
    final correct = task.correctOption.trim().toLowerCase();
    _heardSpeechThisCard = true;
    await _completeCard(
      outcome: normalized == correct
          ? TrainingOutcome.success
          : TrainingOutcome.fail,
    );
  }

  void _syncState() {
    if (_disposed) return;
    final taskKind = _currentTask?.kind;
    final isTimedTask = taskKind?.usesTimer ?? false;
    final isNumberPronunciation =
        taskKind == TrainingTaskKind.numberPronunciation;
    final List<String> expectedTokens = isNumberPronunciation
        ? List<String>.unmodifiable(_answerMatcher.expectedTokens)
        : const <String>[];
    final List<bool> matchedTokens = isNumberPronunciation
        ? List<bool>.unmodifiable(_answerMatcher.matchedTokens)
        : const <bool>[];
    _state = TrainingState(
      status: _status,
      speechReady: _speechReady,
      errorMessage: _errorMessage,
      feedback: _feedback,
      currentTask: _currentTask,
      currentCard: _currentCard,
      displayText: _resolveDisplayText(),
      hintText: _resolveHintText(),
      expectedTokens: expectedTokens,
      matchedTokens: matchedTokens,
      cardDuration: isTimedTask ? _cardTimer.duration : Duration.zero,
      isTimerRunning: isTimedTask && _cardTimer.isRunning,
      isAwaitingRecording: _status == TrainerStatus.waitingRecording,
      isRecording: _isRecording,
      hasRecording: _recordingFile != null,
      isAwaitingPronunciationReview: _awaitingPronunciationReview,
      pronunciationResult: _pronunciationResult,
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
    unawaited(_recordingLevelSubscription?.cancel());
    _soundWaveService.dispose();
    _cardTimer.dispose();
    _speechService.dispose();
    _keepAwakeService.dispose();
    _audioRecorder.dispose();
  }

  void _refreshCardsIfNeeded() {
    final language = _currentLanguage();
    if (_cardsLanguage == language && _cardsById.isNotEmpty) return;
    _cardsLanguage = language;
    final toWords = _languageRouter.numberWordsConverter(language);
    final cards = buildNumberCards(
      language: language,
      toWords: toWords,
    );
    _cardsById = {for (final card in cards) card.id: card};
    _cardIds = _cardsById.keys.toList()..sort();
  }

  Future<void> _loadProgress() async {
    _refreshCardsIfNeeded();
    if (_cardIds.isEmpty) {
      _progressById = {};
      _pool = [];
      return;
    }
    final language = _currentLanguage();
    final progress = await _progressRepository.loadAll(
      _cardIds,
      language: language,
    );
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
    return _languageRouter.currentLanguage;
  }

  TrainingTaskKind? _readDebugForcedTaskKind() {
    if (!kDebugMode) {
      return null;
    }
    return _settingsRepository.readDebugForcedTaskKind();
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

  // TODO: Tune duration per prompt if needed.
  Duration _resolveCardDuration(String prompt) {
    final seconds = _settingsRepository.readAnswerDurationSeconds();
    return Duration(seconds: seconds);
  }

  void _startCardTimer(String prompt) {
    final duration = _resolveCardDuration(prompt);
    _cardTimer.start(duration, _onTimerTimeout);
  }

  String? _resolveHintText() {
    if (!_cardActive || _currentCard == null) return null;
    final maxStreak = _settingsRepository.readHintStreakCount();
    if (maxStreak <= 0 || _consecutiveCorrectAnswers >= maxStreak) {
      return null;
    }
    if (_currentTask?.kind != TrainingTaskKind.numberPronunciation) {
      return null;
    }
    final answers = _currentCard?.answers ?? const <String>[];
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

  String _resolveDisplayText() {
    final task = _currentTask;
    if (task != null) {
      return task.displayText;
    }
    return _currentCard?.displayText ?? '--';
  }

  stt.ListenMode _resolveListenMode() {
    if (_answerMatcher.expectedTokens.length <= 2) {
      return stt.ListenMode.search;
    }
    return stt.ListenMode.dictation;
  }

  int _generatePhraseTaskId(int numberValue, int templateId) {
    // Keep IDs unique while keeping progress keyed to [numberValue].
    return numberValue * 1000 + templateId;
  }

  void _resetCardProgress(NumberPronunciationTask? card) {
    final prompt = card?.prompt ?? '';
    final language = card?.language ?? _currentLanguage();
    final answers = card?.answers ?? const <String>[];
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

  TrainingTaskKind _pickTaskKind({required bool canUsePhrase}) {
    final weightedKinds = <MapEntry<TrainingTaskKind, int>>[
      const MapEntry(
        TrainingTaskKind.numberPronunciation,
        _numberPronunciationWeight,
      ),
      const MapEntry(
        TrainingTaskKind.numberToWord,
        _numberToWordWeight,
      ),
      const MapEntry(
        TrainingTaskKind.wordToNumber,
        _wordToNumberWeight,
      ),
      if (canUsePhrase)
        const MapEntry(
          TrainingTaskKind.phrasePronunciation,
          _phrasePronunciationWeight,
        ),
    ];
    final totalWeight =
        weightedKinds.fold(0, (sum, entry) => sum + entry.value);
    final roll = _random.nextInt(totalWeight);
    var cursor = 0;
    for (final entry in weightedKinds) {
      cursor += entry.value;
      if (roll < cursor) {
        return entry.key;
      }
    }
    return weightedKinds.last.key;
  }

  bool _hasPhraseTemplate(LearningLanguage language, int numberValue) {
    return _languageRouter.hasTemplate(numberValue, language: language);
  }

  int? _pickPoolIndex({
    required LearningLanguage language,
    required bool requirePhrase,
  }) {
    if (_pool.isEmpty) return null;
    if (!requirePhrase) {
      return _random.nextInt(_pool.length);
    }
    final eligible = <int>[];
    for (var i = 0; i < _pool.length; i += 1) {
      final cardId = _pool[i];
      if (_hasPhraseTemplate(language, cardId)) {
        eligible.add(i);
      }
    }
    if (eligible.isEmpty) return null;
    return eligible[_random.nextInt(eligible.length)];
  }

  Future<void> _startNextCard() async {
    if (_status != TrainerStatus.running &&
        _status != TrainerStatus.waitingRecording) {
      return;
    }
    if (_pool.isEmpty) {
      _status = TrainerStatus.finished;
      unawaited(_setKeepAwake(false));
      _syncState();
      return;
    }

    final language = _currentLanguage();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    final forcedTaskKind = _debugForcedTaskKind;
    final requirePhrase =
        forcedTaskKind == TrainingTaskKind.phrasePronunciation;
    await _refreshInternetStatus();
    if (requirePhrase && !_hasInternet) {
      _errorMessage =
          'Premium pronunciation requires an internet connection.';
      _status = TrainerStatus.paused;
      _syncState();
      unawaited(_setKeepAwake(false));
      return;
    }
    final allowPhrase =
        (_premiumPronunciationEnabled && _hasInternet) || requirePhrase;
    final poolIndex = _pickPoolIndex(
      language: language,
      requirePhrase: requirePhrase,
    );
    if (poolIndex == null) {
      if (requirePhrase) {
        _errorMessage =
            'Phrase pronunciation tasks are not available for the selected language.';
        _status = TrainerStatus.paused;
        _syncState();
        unawaited(_setKeepAwake(false));
      }
      return;
    }
    final cardId = _pool[poolIndex];
    final card = _cardsById[cardId];
    if (card == null) return;

    final canUsePhrase =
        allowPhrase && _hasPhraseTemplate(language, card.id);
    if (requirePhrase && !canUsePhrase) {
      _errorMessage =
          'Phrase pronunciation tasks are not available for the selected language.';
      _status = TrainerStatus.paused;
      _syncState();
      unawaited(_setKeepAwake(false));
      return;
    }
    final taskKind =
        forcedTaskKind ?? _pickTaskKind(canUsePhrase: canUsePhrase);

    if (taskKind == TrainingTaskKind.numberPronunciation && !_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        _status = TrainerStatus.paused;
        _cardActive = false;
        _currentTask = null;
        _currentCard = null;
        _currentCardId = null;
        _currentPoolIndex = null;
        _syncState();
        unawaited(_setKeepAwake(false));
        return;
      }
    }

    _currentPoolIndex = poolIndex;
    _currentCardId = cardId;
    _currentCard = card;
    _currentTask = null;
    _currentPhraseTask = null;
    _pronunciationResult = null;
    _recordingFile = null;
    _isRecording = false;
    _awaitingPronunciationReview = false;

    _cardActive = true;
    _heardSpeechThisCard = taskKind != TrainingTaskKind.numberPronunciation;
    _soundWaveService.reset();
    _suppressNextClientError = false;

    switch (taskKind) {
      case TrainingTaskKind.numberToWord:
        final task = _buildNumberToWordTask(card);
        _currentTask = task;
        _status = TrainerStatus.running;
        _startCardTimer(task.prompt);
        _syncState();
        return;
      case TrainingTaskKind.wordToNumber:
        final task = _buildWordToNumberTask(card);
        _currentTask = task;
        _status = TrainerStatus.running;
        _startCardTimer(task.prompt);
        _syncState();
        return;
      case TrainingTaskKind.phrasePronunciation:
        final template = _languageRouter.pickTemplate(
          card.id,
          language: language,
        );
        if (template == null) {
          _currentTask = card;
          _resetCardProgress(card);
          _status = TrainerStatus.running;
          _startCardTimer(card.prompt);
          _syncState();
          await _startListening();
          return;
        }
        _currentPhraseTask = template.toTask(
          value: card.id,
          taskId: _generatePhraseTaskId(card.id, template.id),
        );
        _currentTask = _currentPhraseTask;
        _status = TrainerStatus.waitingRecording;
        _cardTimer.stop();
        _syncState();
        return;
      case TrainingTaskKind.numberPronunciation:
        _currentTask = card;
        _resetCardProgress(card);
        _status = TrainerStatus.running;
        _startCardTimer(card.prompt);
        _syncState();
        await _startListening();
        return;
    }
  }

  NumberToWordTask _buildNumberToWordTask(NumberPronunciationTask card) {
    final language = _currentLanguage();
    final toWords = _languageRouter.numberWordsConverter(language);
    final correct = toWords(card.id);
    final options = <String>{correct};

    while (options.length < numberToWordOptionCount) {
      final candidateId = _cardIds[_random.nextInt(_cardIds.length)];
      if (candidateId == card.id) continue;
      try {
        final option = toWords(candidateId);
        options.add(option);
      } catch (_) {
        // Skip invalid conversions and try another number.
      }
    }

    final shuffled = options.toList()..shuffle(_random);
    return NumberToWordTask(
      id: _generateNumberToWordTaskId(card.id),
      numberValue: card.id,
      prompt: card.prompt,
      correctOption: correct,
      options: shuffled,
    );
  }

  int _generateNumberToWordTaskId(int numberValue) {
    return numberValue * 1000 + 500;
  }

  WordToNumberTask _buildWordToNumberTask(NumberPronunciationTask card) {
    // Prompt is the "word" form (e.g. "forty-two")
    final language = _currentLanguage();
    final toWords = _languageRouter.numberWordsConverter(language);
    final correctWord = toWords(card.id);
    
    // Correct answer is the digit text (e.g. "42")
    final correctOption = card.id.toString();
    final options = <String>{correctOption};

    while (options.length < numberToWordOptionCount) { // Reusing same option count
      final candidateId = _cardIds[_random.nextInt(_cardIds.length)];
      if (candidateId == card.id) continue;
      options.add(candidateId.toString());
    }

    final shuffled = options.toList()..shuffle(_random);
    return WordToNumberTask(
      id: _generateWordToNumberTaskId(card.id),
      numberValue: card.id,
      prompt: correctWord,
      correctOption: correctOption,
      options: shuffled,
    );
  }

  int _generateWordToNumberTaskId(int numberValue) {
    return numberValue * 1000 + 501; // distinct range
  }

  Future<void> _startListening() async {
    if (_currentTask?.kind != TrainingTaskKind.numberPronunciation) {
      return;
    }
    if (_currentCardId == null ||
        _status != TrainerStatus.running ||
        !_cardActive) {
      return;
    }
    final remaining = _remainingCardDuration();
    if (remaining < const Duration(milliseconds: 500)) {
      unawaited(_completeCard(outcome: TrainingOutcome.timeout));
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
    unawaited(_completeCard(outcome: TrainingOutcome.timeout));
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
      await _completeCard(outcome: TrainingOutcome.success);
      return;
    }

    if (_status != TrainerStatus.running || !_cardActive) return;
    if (_remainingCardDuration() <= Duration.zero) {
      await _completeCard(outcome: TrainingOutcome.timeout);
      return;
    }
    await Future.delayed(_listenRestartDelay);
    await _startListening();
  }

  Future<void> _completeCard({
    required TrainingOutcome outcome,
  }) async {
    if (!_cardActive || _currentCardId == null) return;
    _cardActive = false;
    _activeAttemptId = null;
    _cardTimer.stop();

    _soundWaveService.stop();
    await _speechService.stop();

    final isCorrect = outcome == TrainingOutcome.success;
    final isPhrasePronunciation =
        _currentTask?.kind == TrainingTaskKind.phrasePronunciation;
    // Phrase pronunciation tasks are informational only and must not affect learning progress.
    final shouldUpdateProgress =
        !isPhrasePronunciation && outcome != TrainingOutcome.ignore;

    if (shouldUpdateProgress) {
      if (isCorrect) {
        _consecutiveCorrectAnswers += 1;
      } else {
        _consecutiveCorrectAnswers = 0;
      }

      await _updateProgress(isCorrect: isCorrect);
    }

    _showFeedback(outcome: outcome);

    if (_status == TrainerStatus.running) {
      if (_heardSpeechThisCard) {
        _consecutiveSilentCards = 0;
      } else if (shouldUpdateProgress) {
        _consecutiveSilentCards += 1;
      }
      if (_consecutiveSilentCards >= 3) {
        await _pauseTraining();
        return;
      }
    }

    if (_status == TrainerStatus.waitingRecording) {
      _status = TrainerStatus.running;
    }

    await _startNextCard();
  }

  Future<void> _updateProgress({required bool isCorrect}) async {
    final progressKey = _currentTask?.progressId ?? _currentCardId;
    if (progressKey == null) return;
    final language = _currentLanguage();
    final progress = _progressById[progressKey] ?? CardProgress.empty;
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
    _progressById[progressKey] = updated;
    await _progressRepository.save(
      progressKey,
      updated,
      language: language,
    );
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

  void _showFeedback({required TrainingOutcome outcome}) {
    _feedbackTimer?.cancel();
    late final TrainingFeedbackType type;
    late final String text;

    switch (outcome) {
      case TrainingOutcome.success:
        type = TrainingFeedbackType.correct;
        text = 'Correct';
        break;
      case TrainingOutcome.fail:
        type = TrainingFeedbackType.wrong;
        text = 'Wrong';
        break;
      case TrainingOutcome.timeout:
        type = TrainingFeedbackType.timeout;
        text = 'Timeout';
        break;
      case TrainingOutcome.ignore:
        type = TrainingFeedbackType.skipped;
        text = 'Skipped';
        break;
    }

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
    await _stopRecordingSoundWave();
    _cardTimer.stop();

    if (_isRecording) {
      await _audioRecorder.cancel();
      _isRecording = false;
    }

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

  Future<void> _refreshInternetStatus({bool force = false}) async {
    if (!force && _lastInternetCheck != null) {
      final elapsed = DateTime.now().difference(_lastInternetCheck!);
      if (elapsed < _internetCheckCache) {
        return;
      }
    }
    _lastInternetCheck = DateTime.now();
    _hasInternet = await hasInternet();
  }

  Future<void> _startRecordingSoundWave() async {
    await _recordingLevelSubscription?.cancel();
    _soundWaveService.reset();
    _soundWaveService.start();
    _recordingLevelSubscription = _audioRecorder.amplitudeStream.listen(
      _soundWaveService.onSoundLevel,
      onError: (error) {
        _log('Recording sound level error: $error');
      },
    );
  }

  Future<void> _stopRecordingSoundWave() async {
    await _recordingLevelSubscription?.cancel();
    _recordingLevelSubscription = null;
    _soundWaveService.stop();
  }

  String _trimForLog(String value, {int maxLength = 120}) {
    final trimmed = value.trim().replaceAll('\n', ' ');
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength)}...';
  }

  String _formatPronunciationResult(PronunciationAnalysisResult result) {
    final display = result.displayText ?? '';
    final best = result.best;
    if (best == null) {
      return 'Pronunciation result: display="${_trimForLog(display)}" '
          'nBest=${result.nBest.length} best=none';
    }
    return 'Pronunciation result: display="${_trimForLog(display)}" '
        'nBest=${result.nBest.length} '
        'scores(pron=${best.pronScore.toStringAsFixed(1)}, '
        'acc=${best.accuracyScore.toStringAsFixed(1)}, '
        'flu=${best.fluencyScore.toStringAsFixed(1)}, '
        'comp=${best.completenessScore.toStringAsFixed(1)}, '
        'words=${best.words.length})';
  }
}
