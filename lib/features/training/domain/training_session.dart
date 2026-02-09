import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../../../core/logging/app_logger.dart';
import '../languages/registry.dart';
import 'daily_session_stats.dart';
import 'feedback_coordinator.dart';
import 'language_router.dart';
import 'learning_language.dart';
import 'progress_manager.dart';
import 'repositories.dart';
import 'runtimes/listening_runtime.dart';
import 'runtimes/multiple_choice_runtime.dart';
import 'runtimes/number_pronunciation_runtime.dart';
import 'runtimes/phrase_pronunciation_runtime.dart';
import 'runtime_coordinator.dart';
import 'session_helpers.dart';
import 'task_availability.dart';
import 'task_registry.dart';
import 'task_runtime.dart';
import 'task_scheduler.dart';
import 'tasks/number_to_word_task.dart';
import 'tasks/time_pronunciation_task.dart';
import 'training_outcome.dart';
import 'training_services.dart';
import 'training_state.dart';
import 'training_item.dart';
import 'training_task.dart';
import 'time_value.dart';

class TrainingSession {
  TrainingSession({
    required SettingsRepositoryBase settingsRepository,
    required ProgressRepositoryBase progressRepository,
    TrainingServices? services,
    TaskRegistry? taskRegistry,
    void Function()? onStateChanged,
    void Function()? onAutoStop,
  }) : _settingsRepository = settingsRepository,
       _progressRepository = progressRepository,
       _services = services ?? TrainingServices.defaults(),
       _onStateChanged = onStateChanged ?? _noop,
       _onAutoStop = onAutoStop ?? _noop {
    _languageRouter = LanguageRouter(
      settingsRepository: _settingsRepository,
      random: _random,
    );
    _taskRegistry = taskRegistry ?? _buildDefaultRegistry();
    final availabilityRegistry = TaskAvailabilityRegistry(
      providers: [
        SpeechTaskAvailabilityProvider(_services.speech),
        TtsTaskAvailabilityProvider(_services.tts),
        PhraseTaskAvailabilityProvider(),
      ],
    );
    _taskScheduler = TaskScheduler(
      languageRouter: _languageRouter,
      availabilityRegistry: availabilityRegistry,
      internetChecker: _services.internet,
      random: _random,
    );
    _progressManager = ProgressManager(
      progressRepository: _progressRepository,
      languageRouter: _languageRouter,
    );
    _feedbackCoordinator = FeedbackCoordinator(onChanged: _syncState);
    _runtimeCoordinator = RuntimeCoordinator(
      onChanged: _syncState,
      onEvent: _handleRuntimeEvent,
    );
    _refreshCardsIfNeeded();
    _premiumPronunciationEnabled = _settingsRepository
        .readPremiumPronunciationEnabled();
    _debugForcedLearningMethod = _readDebugForcedLearningMethod();
    _debugForcedItemType = _readDebugForcedItemType();
    _syncState();
  }

  static void _noop() {}

  final math.Random _random = math.Random();
  final TrainingServices _services;
  final SettingsRepositoryBase _settingsRepository;
  final ProgressRepositoryBase _progressRepository;
  final void Function() _onStateChanged;
  final void Function() _onAutoStop;
  late final LanguageRouter _languageRouter;
  late final TaskRegistry _taskRegistry;
  late final TaskScheduler _taskScheduler;
  late final ProgressManager _progressManager;
  late final FeedbackCoordinator _feedbackCoordinator;
  late final RuntimeCoordinator _runtimeCoordinator;
  TrainingCelebration? _pendingCelebration;
  int _celebrationEventId = 0;

  bool _premiumPronunciationEnabled = false;
  LearningMethod? _debugForcedLearningMethod;
  TrainingItemType? _debugForcedItemType;

  String? _errorMessage;

  final SilentDetector _silentDetector = SilentDetector();
  final StreakTracker _streakTracker = StreakTracker();

  bool _disposed = false;
  bool _trainingActive = false;

  // Session limits
  DateTime? _sessionStartTime;
  int _sessionCardsCompleted = 0;
  int _sessionTargetCards = 0;

  TrainingState _state = TrainingState.initial();
  TrainingState get state => _state;

  Stream<List<double>> get soundStream => _services.soundWave.stream;

  int get totalCards => _progressManager.totalCards;
  int get learnedCount => _progressManager.learnedCount;
  int get remainingCount => _progressManager.remainingCount;
  bool get hasRemainingCards => _progressManager.hasRemainingCards;
  int get dailyGoalCards => _progressManager.dailySummary().targetToday;
  int get dailyRemainingCards => _progressManager.dailySummary().remainingToday;
  int get sessionCardsCompleted => _sessionCardsCompleted;
  int get sessionTargetCards => _sessionTargetCards;

  bool get premiumPronunciationEnabled => _premiumPronunciationEnabled;
  Future<void> setPremiumPronunciationEnabled(bool enabled) async {
    _premiumPronunciationEnabled = enabled;
    await _settingsRepository.setPremiumPronunciationEnabled(enabled);
    _syncState();
  }

  Future<void> initialize() async {
    await _loadProgress();
    _syncState();
  }

  Future<void> retryInitSpeech() async {
    final runtime = _runtimeCoordinator.runtime;
    if (runtime is NumberPronunciationRuntime) {
      await runtime.handleAction(const RetrySpeechInitAction());
      return;
    }
    await _initSpeechDirect();
    _syncState();
  }

  Future<void> startTraining() async {
    if (_trainingActive) return;
    _pendingCelebration = null;

    _premiumPronunciationEnabled = _settingsRepository
        .readPremiumPronunciationEnabled();
    _debugForcedLearningMethod = _readDebugForcedLearningMethod();
    _debugForcedItemType = _readDebugForcedItemType();
    if (_progressManager.cardsLanguage != _currentLanguage()) {
      await _loadProgress();
    }
    await _taskScheduler.warmUpAvailability(
      language: _currentLanguage(),
      premiumPronunciationEnabled: _premiumPronunciationEnabled,
    );
    if (!_progressManager.hasRemainingCards) {
      _trainingActive = false;
      unawaited(_setKeepAwake(false));
      _syncState();
      return;
    }

    _errorMessage = null;
    _trainingActive = true;
    _silentDetector.reset();
    _streakTracker.reset();
    _runtimeCoordinator.resetInteraction();
    _syncState();
    unawaited(_setKeepAwake(true));
    _resetSessionCounters(targetCards: _initialSessionTargetCards());
    await _startNextCard();
  }

  void _resetSessionCounters({required int targetCards}) {
    _sessionStartTime = DateTime.now();
    _sessionCardsCompleted = 0;
    _sessionTargetCards = targetCards < 0 ? 0 : targetCards;
  }

  Future<void> continueSession() async {
    _resetSessionCounters(targetCards: dailyGoalCards);
    // Clear the stats from state
    _state = TrainingState(
      speechReady: _state.speechReady,
      errorMessage: _state.errorMessage,
      feedback: _state.feedback,
      currentTask: _state.currentTask,
      sessionStats: null,
      celebration: _pendingCelebration,
    );
    // Note: we don't call _syncState here to avoid flicker, just proceed
    _onStateChanged();
    await _startNextCard();
  }

  Future<void> continueAfterCelebration() async {
    if (_pendingCelebration == null) return;
    _pendingCelebration = null;
    _syncState();
    if (!_trainingActive || _disposed) return;
    await _startNextCard();
  }

  Future<void> stopTraining() async {
    _feedbackCoordinator.clear();
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    _services.soundWave.reset();
    _trainingActive = false;
    _errorMessage = null;
    _progressManager.resetSelection();
    _premiumPronunciationEnabled = _settingsRepository
        .readPremiumPronunciationEnabled();
    _debugForcedLearningMethod = _readDebugForcedLearningMethod();
    _debugForcedItemType = _readDebugForcedItemType();
    _pendingCelebration = null;
    _silentDetector.reset();
    _streakTracker.reset();
    _runtimeCoordinator.resetInteraction();
    _syncState();
    unawaited(_setKeepAwake(false));
  }

  Future<void> pauseForOverlay() async {
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    _trainingActive = false;
    _pendingCelebration = null;
    await _setKeepAwake(false);
    _syncState();
  }

  Future<void> restoreAfterOverlay() async {
    await _loadProgress();
    _premiumPronunciationEnabled = _settingsRepository
        .readPremiumPronunciationEnabled();
    _debugForcedLearningMethod = _readDebugForcedLearningMethod();
    _debugForcedItemType = _readDebugForcedItemType();
    _progressManager.resetSelection();
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    _pendingCelebration = null;
    _silentDetector.reset();
    _runtimeCoordinator.resetInteraction();
    _trainingActive = false;
    await _setKeepAwake(false);
    _syncState();
  }

  Future<void> handleAction(TaskAction action) async {
    await _runtimeCoordinator.handleAction(action);
  }

  Future<void> completeCurrentTaskWithOutcome(TrainingOutcome outcome) async {
    if (_runtimeCoordinator.currentTask == null) return;
    await _handleTaskCompleted(outcome);
  }

  Future<void> pauseTaskTimer() async {
    _services.timer.pause();
  }

  Future<void> resumeTaskTimer() async {
    _services.timer.resume();
  }

  int _initialSessionTargetCards() {
    final remaining = dailyRemainingCards;
    return remaining > 0 ? remaining : 0;
  }

  bool _checkSessionLimits() {
    return _sessionCardsCompleted >= _sessionTargetCards;
  }

  void _syncState() {
    if (_disposed) return;
    _state = TrainingState(
      speechReady: _runtimeCoordinator.speechReady,
      errorMessage: _errorMessage,
      feedback: _feedbackCoordinator.feedback,
      currentTask: _runtimeCoordinator.currentTask,
      sessionStats: _state.sessionStats,
      celebration: _pendingCelebration,
    );
    _onStateChanged();
  }

  void dispose() {
    _disposed = true;
    _feedbackCoordinator.dispose();
    unawaited(_runtimeCoordinator.disposeRuntime(clearState: true));
    _services.dispose();
  }

  void _refreshCardsIfNeeded() {
    _progressManager.refreshCardsIfNeeded(_currentLanguage());
  }

  Future<void> _loadProgress() async {
    await _progressManager.loadProgress(_currentLanguage());
  }

  Future<void> _initSpeechDirect() async {
    final result = await _services.speech.initialize(
      onError: _logSpeechError,
      onStatus: (_) {},
    );
    _runtimeCoordinator.updateSpeechReady(result.ready);
    _errorMessage = result.ready ? null : result.errorMessage;
  }

  void _logSpeechError(SpeechRecognitionError error) {
    appLogW(
      'speech',
      'Speech error during init: ${error.errorMsg}',
      error: error,
    );
  }

  LearningLanguage _currentLanguage() {
    return _languageRouter.currentLanguage;
  }

  LearningMethod? _readDebugForcedLearningMethod() {
    if (!kDebugMode) {
      return null;
    }
    return _settingsRepository.readDebugForcedLearningMethod();
  }

  TrainingItemType? _readDebugForcedItemType() {
    if (!kDebugMode) {
      return null;
    }
    return _settingsRepository.readDebugForcedItemType();
  }

  Duration _resolveCardDuration() {
    final seconds = _settingsRepository.readAnswerDurationSeconds();
    return Duration(seconds: seconds);
  }

  String? _resolveHintText(PronunciationTaskData card, LearningMethod kind) {
    if (kind != LearningMethod.numberPronunciation) return null;
    final maxStreak = _settingsRepository.readHintStreakCount();
    if (maxStreak <= 0 || _streakTracker.streak >= maxStreak) {
      return null;
    }
    final answers = card.answers;
    if (answers.isEmpty) return null;

    final prompt = card.prompt.trim().toLowerCase();
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

  TaskRegistry _buildDefaultRegistry() {
    return TaskRegistry({
      LearningMethod.numberPronunciation: (context) {
        final card = context.card;
        return NumberPronunciationRuntime(
          task: card,
          speechService: context.services.speech,
          soundWaveService: context.services.soundWave,
          cardTimer: context.services.timer,
          cardDuration: context.cardDuration,
          hintText: context.hintText,
          onSpeechReady: _handleSpeechReady,
        );
      },
      LearningMethod.valueToText: _buildValueToTextRuntime,
      LearningMethod.textToValue: _buildTextToValueRuntime,
      LearningMethod.listening: _buildListeningRuntime,
      LearningMethod.phrasePronunciation: _buildPhrasePronunciationRuntime,
    });
  }

  void _handleSpeechReady(bool ready, String? errorMessage) {
    _runtimeCoordinator.updateSpeechReady(ready);
    if (ready) {
      _errorMessage = null;
    } else if (errorMessage != null) {
      _errorMessage = errorMessage;
    }
    _syncState();
  }

  TaskRuntime _buildValueToTextRuntime(TaskBuildContext context) {
    final spec = context.card.buildValueToTextSpec(context);
    return MultipleChoiceRuntime(
      kind: LearningMethod.valueToText,
      taskId: context.card.id,
      numberValue: spec.numberValue,
      prompt: spec.prompt,
      correctOption: spec.correctOption,
      options: spec.options,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
    );
  }

  TaskRuntime _buildTextToValueRuntime(TaskBuildContext context) {
    final timeValue = context.card.timeValue;
    if (timeValue != null) {
      final correctWord = context.timeToWords(timeValue);
      final correctOption = timeValue.displayText;
      final options = <String>{correctOption};
      final candidateTimes = _candidateTimeValuesFor(context);

      final maxAttempts = candidateTimes.length * 3 + 5;
      var attempts = 0;
      while (options.length < valueToTextOptionCount &&
          attempts < maxAttempts) {
        final candidate =
            candidateTimes[context.random.nextInt(candidateTimes.length)];
        attempts += 1;
        if (candidate == timeValue) continue;
        options.add(candidate.displayText);
      }

      final shuffled = options.toList()..shuffle(context.random);
      return MultipleChoiceRuntime(
        kind: LearningMethod.textToValue,
        taskId: context.card.id,
        numberValue: null,
        prompt: correctWord,
        correctOption: correctOption,
        options: shuffled,
        cardDuration: context.cardDuration,
        cardTimer: context.services.timer,
      );
    }

    final numberValue = _requireNumberValue(context.card);
    final correctWord = context.toWords(numberValue);
    final correctOption = numberValue.toString();
    final options = <String>{correctOption};
    final candidateIds = _candidateIdsFor(context);

    while (options.length < valueToTextOptionCount) {
      final candidateId =
          candidateIds[context.random.nextInt(candidateIds.length)];
      final candidateValue = candidateId.number!;
      if (candidateValue == numberValue) continue;
      options.add(candidateValue.toString());
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceRuntime(
      kind: LearningMethod.textToValue,
      taskId: context.card.id,
      numberValue: numberValue,
      prompt: correctWord,
      correctOption: correctOption,
      options: shuffled,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
    );
  }

  TaskRuntime _buildListeningRuntime(TaskBuildContext context) {
    final card = context.card;
    final numberValue = card.numberValue;
    final timeValue = card.timeValue;

    String correctOption;
    String speechText;
    final options = <String>{};

    if (numberValue != null) {
      // Number-based listening
      correctOption = numberValue.toString();
      options.add(correctOption);
      final candidateIds = _candidateIdsFor(context);

      while (options.length < valueToTextOptionCount) {
        final candidateId =
            candidateIds[context.random.nextInt(candidateIds.length)];
        final candidateValue = candidateId.number;
        if (candidateValue == null || candidateValue == numberValue) continue;
        options.add(candidateValue.toString());
      }

      try {
        speechText = context.toWords(numberValue);
      } catch (_) {
        speechText = correctOption;
      }
    } else if (timeValue != null) {
      // Time-based listening
      correctOption = timeValue.displayText;
      options.add(correctOption);
      final candidateTimes = _candidateTimeValuesFor(context);

      while (options.length < valueToTextOptionCount) {
        final candidateTime =
            candidateTimes[context.random.nextInt(candidateTimes.length)];
        if (candidateTime == timeValue) continue;
        options.add(candidateTime.displayText);
      }

      try {
        speechText = context.timeToWords(timeValue);
      } catch (_) {
        speechText = correctOption;
      }
    } else {
      throw StateError(
        'Expected either numberValue or timeValue for listening task.',
      );
    }

    final shuffled = options.toList()..shuffle(context.random);
    final voiceId = _settingsRepository.readTtsVoiceId(context.language);

    return ListeningRuntime(
      taskId: context.card.id,
      numberValue: numberValue,
      timeValue: timeValue,
      correctAnswer: correctOption,
      options: shuffled,
      speechText: speechText,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
      ttsService: context.services.tts,
      locale: LanguageRegistry.of(context.language).locale,
      voiceId: voiceId,
    );
  }

  TaskRuntime _buildPhrasePronunciationRuntime(TaskBuildContext context) {
    final numberValue = _requireNumberValue(context.card);
    final template = _languageRouter.pickTemplate(
      numberValue,
      language: context.language,
    );
    if (template == null) {
      return _buildFallbackPronunciationRuntime(context);
    }
    final task = template.toTask(value: numberValue, taskId: context.card.id);
    return PhrasePronunciationRuntime(
      task: task,
      language: context.language,
      audioRecorder: context.services.audioRecorder,
      soundWaveService: context.services.soundWave,
      azureSpeechService: context.services.azure,
    );
  }

  TaskRuntime _buildFallbackPronunciationRuntime(TaskBuildContext context) {
    final card = context.card;
    final hintText =
        context.hintText ??
        _resolveHintText(card, LearningMethod.numberPronunciation);
    return NumberPronunciationRuntime(
      task: card,
      speechService: context.services.speech,
      soundWaveService: context.services.soundWave,
      cardTimer: context.services.timer,
      cardDuration: context.cardDuration,
      hintText: hintText,
      onSpeechReady: _handleSpeechReady,
    );
  }

  Future<void> _handleSessionLimitReached() async {
    final now = DateTime.now();
    final elapsed = _sessionStartTime == null
        ? Duration.zero
        : now.difference(_sessionStartTime!);
    final todayStats = await _recordDailySessionStats(
      now: now,
      elapsed: elapsed,
    );

    final stats = SessionStats(
      cardsCompleted: _sessionCardsCompleted,
      duration: elapsed,
      sessionsCompletedToday: todayStats.sessionsCompleted,
      cardsCompletedToday: todayStats.cardsCompleted,
      durationToday: todayStats.duration,
    );

    await _runtimeCoordinator.disposeRuntime(clearState: true);
    unawaited(_setKeepAwake(false));

    _state = TrainingState(
      speechReady: _state.speechReady,
      errorMessage: null,
      feedback: null,
      currentTask: null,
      sessionStats: stats,
      celebration: _pendingCelebration,
    );
    _onStateChanged();
  }

  Future<DailySessionStats> _recordDailySessionStats({
    required DateTime now,
    required Duration elapsed,
  }) async {
    var todayStats = _settingsRepository.readDailySessionStats(now: now);
    if (_sessionCardsCompleted <= 0) {
      return todayStats;
    }

    todayStats = todayStats.addSession(
      cards: _sessionCardsCompleted,
      sessionDuration: elapsed,
      now: now,
    );
    await _settingsRepository.setDailySessionStats(todayStats);
    return todayStats;
  }

  Future<void> _startNextCard() async {
    if (!_trainingActive) {
      return;
    }

    // Check session limits
    if (_checkSessionLimits()) {
      await _handleSessionLimitReached();
      return;
    }

    if (!_progressManager.hasRemainingCards) {
      _trainingActive = false;
      unawaited(_setKeepAwake(false));
      _syncState();
      return;
    }

    final language = _currentLanguage();
    _debugForcedLearningMethod = _readDebugForcedLearningMethod();
    _debugForcedItemType = _readDebugForcedItemType();
    final scheduleResult = await _taskScheduler.scheduleNext(
      progressManager: _progressManager,
      language: language,
      premiumPronunciationEnabled: _premiumPronunciationEnabled,
      forcedLearningMethod: _debugForcedLearningMethod,
      forcedItemType: _debugForcedItemType,
    );
    if (scheduleResult is TaskScheduleFinished) {
      _trainingActive = false;
      unawaited(_setKeepAwake(false));
      _syncState();
      return;
    }
    if (scheduleResult is TaskSchedulePaused) {
      _errorMessage = scheduleResult.errorMessage;
      await _pauseTraining();
      return;
    }
    if (scheduleResult is! TaskScheduleReady) {
      return;
    }

    final card = _resolveRandomTimeCard(scheduleResult.card, language);
    final taskKind = scheduleResult.method;

    _services.soundWave.reset();
    _errorMessage = null;

    final hintText = _resolveHintText(card, taskKind);
    final context = TaskBuildContext(
      card: card,
      language: language,
      cardIds: _progressManager.cardIds,
      toWords: _languageRouter.numberWordsConverter(language),
      cardDuration: _resolveCardDuration(),
      languageRouter: _languageRouter,
      random: _random,
      services: _services,
      hintText: hintText,
    );

    final runtime = _taskRegistry.create(taskKind, context);
    await _runtimeCoordinator.attach(runtime);
  }

  List<TrainingItemId> _candidateIdsFor(TaskBuildContext context) {
    final currentType = context.card.id.type;
    return context.cardIds
        .where((itemId) => itemId.type == currentType && itemId.number != null)
        .toList();
  }

  PronunciationTaskData _resolveRandomTimeCard(
    PronunciationTaskData card,
    LearningLanguage language,
  ) {
    if (card.id.type != TrainingItemType.timeRandom) return card;
    final timeValue = TimeValue(
      hour: _random.nextInt(24),
      minute: _random.nextInt(60),
    );
    return TimePronunciationTask.forTime(
      id: card.id,
      timeValue: timeValue,
      language: language,
      toWords: (value) =>
          _languageRouter.timeToWords(value, language: language),
    );
  }

  List<TimeValue> _candidateTimeValuesFor(TaskBuildContext context) {
    final currentType = context.card.id.type;
    final values = context.cardIds
        .where((itemId) => itemId.type == currentType && itemId.time != null)
        .map((itemId) => itemId.time!)
        .toList();
    if (values.isNotEmpty) return values;

    final generated = <TimeValue>{};
    while (generated.length < 24) {
      generated.add(
        TimeValue(
          hour: context.random.nextInt(24),
          minute: context.random.nextInt(60),
        ),
      );
    }
    return generated.toList();
  }

  int _requireNumberValue(PronunciationTaskData card) {
    final numberValue = card.numberValue;
    if (numberValue == null) {
      throw StateError('Expected a number-based pronunciation card.');
    }
    return numberValue;
  }

  void _handleRuntimeEvent(TaskEvent event) {
    if (_disposed) return;
    if (event is TaskError) {
      _errorMessage = event.message;
      if (event.shouldPause) {
        unawaited(_pauseTraining());
      } else {
        _syncState();
      }
      return;
    }
    if (event is TaskCompleted) {
      unawaited(_handleTaskCompleted(event.outcome));
    }
  }

  Future<void> _handleTaskCompleted(TrainingOutcome outcome) async {
    final taskState = _runtimeCoordinator.currentTask;
    if (taskState == null) return;
    await _runtimeCoordinator.disposeRuntime(clearState: false);

    final affectsProgress = taskState.affectsProgress;
    var learnedNow = false;
    var poolEmptyAfterLearn = false;
    if (affectsProgress) {
      final isCorrect = outcome == TrainingOutcome.correct;
      final isSkipped =
          outcome == TrainingOutcome.timeout ||
          outcome == TrainingOutcome.skipped;
      _streakTracker.record(isCorrect);
      _sessionCardsCompleted++;

      final attemptResult = await _progressManager.recordAttempt(
        progressKey: taskState.taskId,
        isCorrect: isCorrect,
        isSkipped: isSkipped,
        language: _currentLanguage(),
      );
      final clusterLabel = attemptResult.newCluster ? 'new' : 'existing';
      appLogI(
        'progress',
        'Attempt: kind=${taskState.kind.name} id=${taskState.taskId} '
            'outcome=${outcome.name} correct=$isCorrect skipped=$isSkipped '
            'cluster=$clusterLabel',
      );
      learnedNow = attemptResult.learned;
      poolEmptyAfterLearn = attemptResult.poolEmpty;
      if (learnedNow) {
        await _queueCelebration();
      }
      if (learnedNow && poolEmptyAfterLearn) {
        _trainingActive = false;
        unawaited(_setKeepAwake(false));
        _syncState();
      }
    } else {
      appLogI(
        'progress',
        'Attempt: kind=${taskState.kind.name} id=${taskState.taskId} '
            'outcome=${outcome.name} affectsProgress=false',
      );
    }

    final feedbackHold = _feedbackCoordinator.show(outcome);

    _silentDetector.record(
      interacted: _runtimeCoordinator.taskHadUserInteraction,
      affectsProgress: affectsProgress,
    );
    if (_silentDetector.shouldStop) {
      await stopTraining();
      _onAutoStop();
      return;
    }

    await feedbackHold;
    if (_disposed) return;
    if (_pendingCelebration != null) {
      return;
    }
    if (!_trainingActive) {
      return;
    }

    await _startNextCard();
  }

  Future<void> _queueCelebration() async {
    try {
      final nextCounter = _settingsRepository.readCelebrationCounter() + 1;
      await _settingsRepository.setCelebrationCounter(nextCounter);
      _celebrationEventId += 1;
      _pendingCelebration = TrainingCelebration(
        eventId: _celebrationEventId,
        counter: nextCounter,
      );
      _syncState();
    } catch (error, st) {
      appLogW(
        'celebration',
        'Failed to queue celebration reward',
        error: error,
        st: st,
      );
    }
  }

  Future<void> _pauseTraining() async {
    await _runtimeCoordinator.disposeRuntime(clearState: false);
    _trainingActive = false;
    _syncState();
    unawaited(_setKeepAwake(false));
  }

  Future<void> _setKeepAwake(bool enabled) async {
    await _services.keepAwake.setEnabled(enabled);
  }
}
