import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../../../core/logging/app_logger.dart';
import 'feedback_coordinator.dart';
import 'language_router.dart';
import 'learning_language.dart';
import 'progress_manager.dart';
import 'repositories.dart';
import 'runtimes/number_pronunciation_runtime.dart';
import 'runtime_coordinator.dart';
import 'session_lifecycle_tracker.dart';
import 'session_progress_plan.dart';
import 'session_helpers.dart';
import 'session_stats_recorder.dart';
import 'study_streak_service.dart';
import 'task_availability.dart';
import 'task_card_flow.dart';
import 'task_progress_recorder.dart';
import 'task_registry.dart';
import 'task_runtime.dart';
import 'task_runtime_factory.dart';
import 'task_scheduler.dart';
import 'task_state.dart';
import 'training_celebration_formatter.dart';
import 'training_outcome.dart';
import 'training_services.dart';
import 'training_state.dart';
import 'training_item.dart';
import 'training_task.dart';

class TrainingSession {
  TrainingSession({
    required SettingsRepositoryBase settingsRepository,
    required ProgressRepositoryBase progressRepository,
    TrainingServices? services,
    TaskRegistry? taskRegistry,
    TaskRuntimeFactory? runtimeFactory,
    void Function()? onStateChanged,
    void Function()? onAutoStop,
  }) : _settingsRepository = settingsRepository,
       _services = services ?? TrainingServices.defaults(),
       _onStateChanged = onStateChanged ?? _noop,
       _onAutoStop = onAutoStop ?? _noop {
    _languageRouter = LanguageRouter(
      settingsRepository: _settingsRepository,
      random: _random,
    );
    final resolvedRuntimeFactory =
        runtimeFactory ??
        TaskRuntimeFactory(
          settingsRepository: _settingsRepository,
          languageRouter: _languageRouter,
          onSpeechReady: _handleSpeechReady,
        );
    _taskRegistry =
        taskRegistry ?? resolvedRuntimeFactory.buildDefaultRegistry();
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
    final studyStreakService = StudyStreakService(
      settingsRepository: _settingsRepository,
    );
    _sessionStatsRecorder = SessionStatsRecorder(
      settingsRepository: _settingsRepository,
      studyStreakService: studyStreakService,
    );
    _progressManager = ProgressManager(
      progressRepository: progressRepository,
      languageRouter: _languageRouter,
    );
    _taskProgressRecorder = TaskProgressRecorder(
      progressManager: _progressManager,
      sessionTracker: _sessionTracker,
    );
    _taskCardFlow = TaskCardFlow(
      random: _random,
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
  final void Function() _onStateChanged;
  final void Function() _onAutoStop;
  late final LanguageRouter _languageRouter;
  late final TaskRegistry _taskRegistry;
  late final TaskScheduler _taskScheduler;
  late final ProgressManager _progressManager;
  late final SessionStatsRecorder _sessionStatsRecorder;
  late final TaskCardFlow _taskCardFlow;
  late final TaskProgressRecorder _taskProgressRecorder;
  late final FeedbackCoordinator _feedbackCoordinator;
  late final RuntimeCoordinator _runtimeCoordinator;
  final SessionLifecycleTracker _sessionTracker = SessionLifecycleTracker();
  final TrainingCelebrationFormatter _celebrationFormatter =
      const TrainingCelebrationFormatter();
  TrainingCelebration? _pendingCelebration;
  int _celebrationEventId = 0;

  bool _premiumPronunciationEnabled = false;
  LearningMethod? _debugForcedLearningMethod;
  TrainingItemType? _debugForcedItemType;

  String? _errorMessage;

  final SilentDetector _silentDetector = SilentDetector();
  bool _disposed = false;
  bool _trainingActive = false;

  TrainingState _state = TrainingState.initial();
  TrainingState get state => _state;

  Stream<List<double>> get soundStream => _services.soundWave.stream;

  int get totalCards => _progressManager.totalCards;
  int get learnedCount => _progressManager.learnedCount;
  int get remainingCount => _progressManager.remainingCount;
  bool get hasRemainingCards => _progressManager.hasRemainingCards;
  int get dailyGoalCards => _progressManager.dailySummary().targetToday;
  int get dailyRemainingCards => _progressManager.dailySummary().remainingToday;
  int get sessionCardsCompleted => _sessionTracker.cardsCompleted;
  int get sessionTargetCards => _sessionTracker.targetCards;

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
    _runtimeCoordinator.resetInteraction();
    _syncState();
    unawaited(_setKeepAwake(true));
    _resetSessionCounters(targetCards: _initialSessionTargetCards());
    await _startNextCard();
  }

  void _resetSessionCounters({required int targetCards}) {
    _sessionTracker.reset(targetCards: targetCards);
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
    await _persistCurrentSessionIfNeeded();
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

  Future<void> completeCurrentTaskWithOutcome(
    TrainingOutcome outcome, {
    bool simulatedUserInteraction = false,
  }) async {
    if (_runtimeCoordinator.currentTask == null) return;
    await _handleTaskCompleted(
      outcome,
      simulatedUserInteraction: simulatedUserInteraction,
    );
  }

  Future<void> pauseTaskTimer() async {
    _services.timer.pause();
    await _runtimeCoordinator.handleAction(const RefreshTimerAction());
  }

  Future<void> resumeTaskTimer() async {
    _services.timer.resume();
    await _runtimeCoordinator.handleAction(const RefreshTimerAction());
  }

  int _initialSessionTargetCards() {
    final summary = _progressManager.dailySummary();
    final sessionSize = SessionProgressPlan.normalizeSessionSize(
      summary.targetToday,
    );
    return SessionProgressPlan.cardsToFinishCurrentSession(
      cardsCompletedToday: summary.completedToday,
      sessionSize: sessionSize,
    );
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
    if (_disposed) return;
    _disposed = true;
    _feedbackCoordinator.dispose();
    unawaited(
      _runtimeCoordinator
          .disposeRuntime(clearState: true)
          .whenComplete(_services.dispose),
    );
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

  Duration _resolveCardDuration(TrainingItemType type) {
    switch (type) {
      case TrainingItemType.digits:
        return const Duration(seconds: 10);
      case TrainingItemType.base:
      case TrainingItemType.hundreds:
      case TrainingItemType.thousands:
      case TrainingItemType.timeExact:
      case TrainingItemType.timeQuarter:
      case TrainingItemType.timeHalf:
      case TrainingItemType.timeRandom:
        return const Duration(seconds: 15);
      case TrainingItemType.phone33x3:
      case TrainingItemType.phone3222:
      case TrainingItemType.phone2322:
        return const Duration(seconds: 30);
    }
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

  Future<void> _handleSessionLimitReached() async {
    final now = DateTime.now();
    final elapsed = _sessionTracker.elapsed(now: now);
    final todayStats = await _sessionStatsRecorder.record(
      cardsCompleted: _sessionTracker.cardsCompleted,
      elapsed: elapsed,
      now: now,
    );
    if (_sessionTracker.hasCompletedCards) {
      _sessionTracker.markStatsPersisted();
    }

    final dailySummary = _progressManager.dailySummary(now: now);
    final stats = SessionStats(
      cardsCompleted: _sessionTracker.cardsCompleted,
      duration: elapsed,
      sessionsCompletedToday: todayStats.sessionsCompleted,
      cardsCompletedToday: dailySummary.completedToday,
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

  Future<void> _persistCurrentSessionIfNeeded() async {
    if (_sessionTracker.statsPersisted || !_sessionTracker.hasCompletedCards) {
      return;
    }
    if (_sessionTracker.startedAt == null) {
      return;
    }
    final now = DateTime.now();
    await _sessionStatsRecorder.record(
      cardsCompleted: _sessionTracker.cardsCompleted,
      elapsed: _sessionTracker.elapsed(now: now),
      now: now,
    );
    if (_sessionTracker.hasCompletedCards) {
      _sessionTracker.markStatsPersisted();
    }
  }

  Future<void> _startNextCard() async {
    if (!_trainingActive) {
      return;
    }

    // Check session limits
    if (_sessionTracker.reachedLimit) {
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

    final card = _taskCardFlow.resolveDynamicCard(
      scheduleResult.card,
      language,
    );
    final taskKind = scheduleResult.method;

    _services.soundWave.reset();
    _errorMessage = null;

    final cardProgress = _progressManager.progressFor(card.progressId);
    final hintVisibleUntilCorrectStreak = _progressManager
        .hintVisibleUntilCorrectStreak(card.progressId.type);
    final hintText = _taskCardFlow.resolveHintText(
      card: card,
      method: taskKind,
      consecutiveCorrect: cardProgress.consecutiveCorrect,
      hintVisibleUntilCorrectStreak: hintVisibleUntilCorrectStreak,
    );
    final context = TaskBuildContext(
      card: card,
      language: language,
      cardIds: _progressManager.cardIds,
      toWords: _languageRouter.numberWordsConverter(language),
      cardDuration: _resolveCardDuration(card.id.type),
      languageRouter: _languageRouter,
      random: _random,
      services: _services,
      hintText: hintText,
    );

    final runtime = _taskRegistry.create(taskKind, context);
    await _runtimeCoordinator.attach(runtime);
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

  Future<void> _handleTaskCompleted(
    TrainingOutcome outcome, {
    bool simulatedUserInteraction = false,
  }) async {
    final taskState = _runtimeCoordinator.currentTask;
    if (taskState == null) return;
    await _runtimeCoordinator.disposeRuntime(clearState: false);

    final progressUpdate = await _taskProgressRecorder.record(
      taskState: taskState,
      outcome: outcome,
      language: _currentLanguage(),
    );
    if (progressUpdate.affectsProgress) {
      if (progressUpdate.learned) {
        await _queueCelebration(taskState: taskState);
      }
    }

    final feedbackHold = _feedbackCoordinator.show(outcome);

    _silentDetector.record(
      interacted:
          simulatedUserInteraction ||
          _runtimeCoordinator.taskHadUserInteraction,
      affectsProgress: progressUpdate.affectsProgress,
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

  Future<void> _queueCelebration({required TaskState taskState}) async {
    try {
      final now = DateTime.now();
      final dailySummary = _progressManager.dailySummary(now: now);
      final sessionTargetCards = _sessionTracker.celebrationTargetCards();
      final nextCounter = _settingsRepository.readCelebrationCounter() + 1;
      await _settingsRepository.setCelebrationCounter(nextCounter);
      _celebrationEventId += 1;
      _pendingCelebration = TrainingCelebration(
        eventId: _celebrationEventId,
        counter: nextCounter,
        masteredText: _celebrationFormatter.masteredText(taskState),
        learningMethodLabel: taskState.kind.label,
        categoryLabel: _celebrationFormatter.categoryLabel(
          taskState.taskId.type,
        ),
        sessionCardsCompleted: _sessionTracker.cardsCompleted,
        sessionTargetCards: sessionTargetCards,
        cardsLearnedTotal: _progressManager.learnedCount,
        cardsRemainingTotal: _progressManager.remainingCount,
        cardsCompletedToday: dailySummary.completedToday,
        cardsTargetToday: dailySummary.targetToday,
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
