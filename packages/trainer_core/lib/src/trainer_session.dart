import 'dart:async';
import 'dart:math' as math;

import 'app_definition.dart';
import 'base_language_profile.dart';
import 'core/logging/app_logger.dart';
import 'exercise_option_shuffler.dart';
import 'exercise_models.dart';
import 'feedback_coordinator.dart';
import 'progress_manager.dart';
import 'runtime_coordinator.dart';
import 'serialized_operation_queue.dart';
import 'runtimes/choice_runtime.dart';
import 'runtimes/listen_and_choose_runtime.dart';
import 'runtimes/review_pronunciation_runtime.dart';
import 'runtimes/speak_runtime.dart';
import 'session_lifecycle_tracker.dart';
import 'session_progress_plan.dart';
import 'session_stats_recorder.dart';
import 'study_streak_service.dart';
import 'task_availability.dart';
import 'task_card_flow.dart';
import 'task_progress_recorder.dart';
import 'task_runtime.dart';
import 'task_scheduler.dart';
import 'trainer_repositories.dart';
import 'trainer_services.dart';
import 'trainer_session_phase.dart';
import 'trainer_state.dart';
import 'training/domain/learning_language.dart';
import 'training/domain/silent_detector.dart';

class TrainerSession {
  TrainerSession({
    required TrainingAppDefinition appDefinition,
    required SettingsRepositoryBase settingsRepository,
    required ProgressRepositoryBase progressRepository,
    TrainingServices? services,
    void Function()? onStateChanged,
    void Function()? onAutoStop,
  }) : _appDefinition = appDefinition,
       _settingsRepository = settingsRepository,
       _services = services ?? TrainingServices.defaults(),
       _onStateChanged = onStateChanged ?? _noop,
       _onAutoStop = onAutoStop ?? _noop {
    _optionShuffler = ExerciseOptionShuffler(_random);
    _progressManager = ProgressManager(
      progressRepository: progressRepository,
      catalog: appDefinition.catalog,
    );
    _taskProgressRecorder = TaskProgressRecorder(
      progressManager: _progressManager,
      sessionTracker: _sessionTracker,
    );
    _feedbackCoordinator = FeedbackCoordinator(onChanged: _syncState);
    _runtimeCoordinator = RuntimeCoordinator(
      onChanged: _syncState,
      onEvent: _handleRuntimeEvent,
    );
    _taskScheduler = TaskScheduler(
      availabilityRegistry: TaskAvailabilityRegistry(
        providers: [
          SpeechTaskAvailabilityProvider(_services.speech),
          TtsTaskAvailabilityProvider(_services.tts),
          ReviewPronunciationAvailabilityProvider(),
        ],
      ),
      internetChecker: _services.internet,
      random: _random,
    );
    _sessionStatsRecorder = SessionStatsRecorder(
      settingsRepository: settingsRepository,
      studyStreakService: StudyStreakService(
        settingsRepository: settingsRepository,
      ),
    );
    _premiumPronunciationEnabled = _settingsRepository
        .readPremiumPronunciationEnabled();
    _syncState();
  }

  static void _noop() {}
  final TrainingAppDefinition _appDefinition;
  final SettingsRepositoryBase _settingsRepository;
  final TrainingServices _services;
  void Function() _onStateChanged;
  final void Function() _onAutoStop;
  final SilentDetector _silentDetector = SilentDetector();

  final math.Random _random = math.Random();
  final SessionLifecycleTracker _sessionTracker = SessionLifecycleTracker();
  final TaskCardFlow _taskCardFlow = const TaskCardFlow();
  static const Duration _fastSpeechCorrectFeedbackDuration = Duration(
    milliseconds: 250,
  );
  late final ExerciseOptionShuffler _optionShuffler;
  late ProgressManager _progressManager;
  late TaskProgressRecorder _taskProgressRecorder;
  late FeedbackCoordinator _feedbackCoordinator;
  late RuntimeCoordinator _runtimeCoordinator;
  late TaskScheduler _taskScheduler;
  late SessionStatsRecorder _sessionStatsRecorder;

  bool _premiumPronunciationEnabled = false;
  String? _debugForcedMode;
  String? _debugForcedFamilyKey;
  bool _stopRequested = false;
  bool _disposed = false;
  bool _disposeRequested = false;
  Future<void>? _disposeFuture;
  final SerializedOperationQueue _operations = SerializedOperationQueue();
  TrainerSessionPhase _phase = TrainerSessionPhase.idle;
  String? _errorMessage;
  SessionStats? _sessionStats;
  TrainingCelebration? _pendingCelebration;
  int _celebrationEventId = 0;
  TrainingState _state = TrainingState.initial();

  bool get _shouldStop => _stopRequested || _disposeRequested || _disposed;
  bool get _isTrainingLifecycleActive =>
      _phase == TrainerSessionPhase.starting ||
      _phase == TrainerSessionPhase.active ||
      _phase == TrainerSessionPhase.transitioning;

  TrainingState get state => _state;
  Stream<List<double>> get soundStream => _services.soundWave.stream;
  int get dailyGoalCards => _progressManager.dailySummary().targetToday;
  int get sessionCardsCompleted => _sessionTracker.cardsCompleted;
  int get sessionTargetCards => _sessionTracker.targetCards;
  TrainerSessionPhase get phase => _phase;

  set onStateChanged(void Function() callback) {
    _onStateChanged = callback;
  }

  Future<void> initialize() => _enqueueCommand(
    name: 'initialize',
    operation: _initializeCore,
    failurePolicy: TrainerCommandFailurePolicy.reportOnly,
  );

  Future<void> _initializeCore() async {
    await _loadProgress();
    _syncState();
  }

  Future<void> retryInitSpeech() => _enqueueCommand(
    name: 'retryInitSpeech',
    operation: _retryInitSpeechCore,
    failurePolicy: TrainerCommandFailurePolicy.pauseTraining,
  );

  Future<void> _retryInitSpeechCore() async {
    final runtime = _runtimeCoordinator.runtime;
    if (runtime is SpeakRuntime) {
      await runtime.handleAction(const RetrySpeechInitAction());
      return;
    }
    await _syncSpeechAvailability();
  }

  Future<void> startTraining() => _enqueueCommand(
    name: 'startTraining',
    operation: _startTrainingCore,
    failurePolicy: TrainerCommandFailurePolicy.pauseTraining,
  );

  Future<void> _startTrainingCore() async {
    if (_phase == TrainerSessionPhase.starting ||
        _phase == TrainerSessionPhase.active ||
        _phase == TrainerSessionPhase.transitioning ||
        _disposeRequested) {
      return;
    }
    _stopRequested = false;
    _transitionTo(TrainerSessionPhase.starting, reason: 'start requested');
    _sessionStats = null;
    _pendingCelebration = null;
    _premiumPronunciationEnabled = _settingsRepository
        .readPremiumPronunciationEnabled();
    _debugForcedMode = _settingsRepository.readDebugForcedMode();
    _debugForcedFamilyKey = _settingsRepository.readDebugForcedFamilyKey();

    final context = _currentLanguageContext();
    if (_progressManager.cardsContext != context) {
      await _loadProgress();
      if (_shouldStop) return;
    }
    await _taskScheduler.warmUpAvailability(
      language: context.learningLanguage,
      profile: _appDefinition.profileOf(context.learningLanguage),
      premiumPronunciationEnabled: _premiumPronunciationEnabled,
      requestSpeechPermission: _catalogSupportsMode(
        context,
        ExerciseMode.speak,
      ),
    );
    if (_shouldStop) return;
    if (!_progressManager.hasRemainingCards) {
      await _completeSessionCore(reason: SessionCompletionReason.noCards);
      return;
    }
    _runtimeCoordinator.resetInteraction();
    _silentDetector.reset();
    _errorMessage = null;
    _resetSessionCounters(targetCards: _initialSessionTargetCards());
    await _services.keepAwake.setEnabled(true);
    if (_shouldStop) return;
    await _startNextCardCore();
  }

  Future<void> continueSession() => _enqueueCommand(
    name: 'continueSession',
    operation: _continueSessionCore,
    failurePolicy: TrainerCommandFailurePolicy.pauseTraining,
  );

  Future<void> _continueSessionCore() async {
    if (_phase != TrainerSessionPhase.sessionCompleted || _disposeRequested) {
      return;
    }
    _stopRequested = false;
    _transitionTo(TrainerSessionPhase.starting, reason: 'continue requested');
    _silentDetector.reset();
    _resetSessionCounters(targetCards: dailyGoalCards);
    _sessionStats = null;
    _errorMessage = null;
    _pendingCelebration = null;
    await _services.keepAwake.setEnabled(true);
    if (_shouldStop) return;
    await _startNextCardCore();
  }

  Future<void> continueAfterCelebration() => _enqueueCommand(
    name: 'continueAfterCelebration',
    operation: _continueAfterCelebrationCore,
    failurePolicy: TrainerCommandFailurePolicy.pauseTraining,
  );

  Future<void> _continueAfterCelebrationCore() async {
    if (_pendingCelebration == null) {
      return;
    }
    _pendingCelebration = null;
    _syncState();
    if (!_isTrainingLifecycleActive || _disposed) {
      return;
    }
    await _startNextCardCore();
  }

  Future<void> stopTraining() {
    if (_disposed || _disposeRequested) return Future<void>.value();
    _stopRequested = true;
    _feedbackCoordinator.clear();
    _runtimeCoordinator.requestCancellation();
    return _enqueueCommand(
      name: 'stopTraining',
      operation: _stopTrainingCore,
      failurePolicy: TrainerCommandFailurePolicy.normalizeToIdle,
      allowWhenStopRequested: true,
    );
  }

  Future<void> _stopTrainingCore() async {
    if (_disposed || _phase == TrainerSessionPhase.disposed) {
      return;
    }
    if (_phase == TrainerSessionPhase.idle) {
      if (!_disposeRequested) _stopRequested = false;
      return;
    }
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      if (_phase != TrainerSessionPhase.stopping) {
        _transitionTo(TrainerSessionPhase.stopping, reason: 'stop requested');
      }
      await _stopResourcesCore(persistSession: true, finalDispose: false);
    } catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    } finally {
      _progressManager.resetSelection();
      _runtimeCoordinator.resetInteraction();
      _sessionStats = null;
      _pendingCelebration = null;
      _errorMessage = null;
      if (_disposeRequested) {
        // Final disposal owns the transition to disposed.
      } else if (_phase == TrainerSessionPhase.stopping) {
        _transitionTo(TrainerSessionPhase.idle, reason: 'stop normalized');
      }
      if (!_disposeRequested) _stopRequested = false;
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStackTrace!);
    }
  }

  Future<void> _stopResourcesCore({
    required bool persistSession,
    required bool finalDispose,
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    Future<void> attempt(String name, Future<void> Function() operation) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        appLogE(
          'trainer',
          '$name failed during lifecycle cleanup',
          error: error,
          st: stackTrace,
        );
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    _feedbackCoordinator.clear();
    _runtimeCoordinator.requestCancellation();
    if (persistSession) {
      await attempt('session persistence', _persistCurrentSessionIfNeeded);
    }
    await attempt(
      'runtime disposal',
      () => _runtimeCoordinator.disposeRuntime(clearState: true),
    );
    await attempt(
      'keep-awake disable',
      () => _services.keepAwake.setEnabled(false),
    );
    if (firstError != null && !finalDispose) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> pauseTaskTimer() => _enqueueCommand(
    name: 'pauseTaskTimer', operation: _pauseTaskTimerCore,
    failurePolicy: TrainerCommandFailurePolicy.pauseTraining,
  );
  Future<void> _pauseTaskTimerCore() async {
    await _runtimeCoordinator.handleAction(const PauseTaskAction());
  }

  Future<void> resumeTaskTimer() => _enqueueCommand(
    name: 'resumeTaskTimer', operation: _resumeTaskTimerCore,
    failurePolicy: TrainerCommandFailurePolicy.pauseTraining,
  );
  Future<void> _resumeTaskTimerCore() async {
    await _runtimeCoordinator.handleAction(const ResumeTaskAction());
  }

  Future<void> handleAction(TaskAction action) => _enqueueCommand(
    name: 'handleAction',
    operation: () => _handleActionCore(action),
    failurePolicy: TrainerCommandFailurePolicy.pauseTraining,
  );
  Future<void> _handleActionCore(TaskAction action) async {
    if (_phase != TrainerSessionPhase.active) {
      return;
    }
    await _runtimeCoordinator.handleAction(action);
  }

  Future<void> completeCurrentTaskWithOutcome(
    TrainingOutcome outcome, {
    bool simulatedUserInteraction = false,
  }) => _enqueueCommand(
    name: 'completeCurrentTask',
    operation: () => _completeCurrentTaskCore(
      outcome,
      simulatedUserInteraction: simulatedUserInteraction,
    ),
    failurePolicy: TrainerCommandFailurePolicy.pauseTraining,
  );

  void dispose() {
    unawaited(disposeAsync());
  }

  Future<void> disposeAsync() {
    _disposeRequested = true;
    _stopRequested = true;
    _feedbackCoordinator.clear();
    _runtimeCoordinator.requestCancellation();
    return _disposeFuture ??= _enqueueCommand(
      name: 'dispose',
      operation: _disposeCore,
      failurePolicy: TrainerCommandFailurePolicy.finalDispose,
      allowWhenStopRequested: true,
      allowWhenDisposeRequested: true,
    ).whenComplete(_operations.close);
  }

  Future<void> _disposeCore() async {
    if (_disposed) return;
    Object? failure;
    StackTrace? failureStackTrace;
    Future<void> attempt(String component, FutureOr<void> Function() operation) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        appLogE('trainer', '$component failed during final disposal', error: error, st: stackTrace);
        failure ??= error;
        failureStackTrace ??= stackTrace;
      }
    }
    if (_phase != TrainerSessionPhase.stopping &&
        _phase != TrainerSessionPhase.idle) {
      _transitionTo(TrainerSessionPhase.stopping, reason: 'dispose requested');
    }
    await attempt('feedback disposal', _feedbackCoordinator.dispose);
    await attempt('resource cleanup', () => _stopResourcesCore(
      persistSession: true,
      finalDispose: true,
    ));
    await attempt('runtime coordinator close', _runtimeCoordinator.close);
    await attempt('services disposal', _services.dispose);
    _disposed = true;
    if (_phase != TrainerSessionPhase.disposed) {
      _transitionTo(TrainerSessionPhase.disposed, reason: 'dispose completed');
    }
    if (failure != null) Error.throwWithStackTrace(failure!, failureStackTrace!);
  }

  Future<void> _loadProgress() async {
    final context = _currentLanguageContext();
    await _progressManager.loadProgress(
      context.learningLanguage,
      baseLanguage: context.baseLanguage,
    );
  }

  TrainingLanguageContext _currentLanguageContext() {
    return TrainingLanguageContext(
      baseLanguage: _currentBaseLanguage(),
      learningLanguage: _currentLanguage(),
    );
  }

  LearningLanguage _currentBaseLanguage() {
    final current = _settingsRepository.readBaseLanguage();
    if (_appDefinition.supportedLanguages.contains(current)) {
      return current;
    }
    final defaultLanguage = _appDefinition.config.defaultBaseLanguage;
    if (_appDefinition.supportedLanguages.contains(defaultLanguage)) {
      return defaultLanguage;
    }
    return _currentLanguage();
  }

  LearningLanguage _currentLanguage() {
    final current = _settingsRepository.readLearningLanguage();
    if (_appDefinition.supportedLanguages.contains(current)) {
      return current;
    }
    return _appDefinition.supportedLanguages.first;
  }

  BaseLanguageProfile _currentProfile() {
    return _appDefinition.profileOf(_currentLanguage());
  }

  bool _catalogSupportsMode(
    TrainingLanguageContext context,
    ExerciseMode mode,
  ) {
    final snapshot = _appDefinition.catalog.buildForContext(context);
    return snapshot.cards.any(
      (card) => card.family.supportedModes.contains(mode),
    );
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

  void _resetSessionCounters({required int targetCards}) {
    _sessionTracker.reset(targetCards: targetCards);
  }

  void _syncState() {
    if (_disposed) {
      return;
    }
    _state = TrainingState(
      errorMessage: _errorMessage,
      feedback: _feedbackCoordinator.feedback,
      currentTask: _runtimeCoordinator.currentTask,
      sessionStats: _sessionStats,
      celebration: _pendingCelebration,
      phase: _phase,
    );
    _state.debugAssertInvariants();
    _onStateChanged();
  }

  Future<void> _syncSpeechAvailability() async {
    final result = await _services.speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    if (_shouldStop) return;
    _runtimeCoordinator.updateSpeechReady(result.ready);
    _errorMessage = result.ready ? null : result.errorMessage;
    _syncState();
  }

  Future<void> _handleSessionLimitReached() =>
      _completeSessionCore(reason: SessionCompletionReason.limitReached);

  Future<void> _completeSessionCore({
    required SessionCompletionReason reason,
  }) async {
    if (_shouldStop || _phase == TrainerSessionPhase.sessionCompleted) return;
    appLogD('trainer', 'session completion started');
    if (_phase == TrainerSessionPhase.active) {
      _transitionTo(
        TrainerSessionPhase.transitioning,
        reason: 'session completion: ${reason.name}',
      );
    }
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
    if (_shouldStop) return;
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    if (_shouldStop) return;
    await _services.keepAwake.setEnabled(false);
    if (_shouldStop) return;
    _sessionStats = SessionStats(
      cardsCompleted: _sessionTracker.cardsCompleted,
      duration: elapsed,
      sessionsCompletedToday: todayStats.sessionsCompleted,
      cardsCompletedToday: dailySummary.completedToday,
      durationToday: todayStats.duration,
    );
    _errorMessage = null;
    _feedbackCoordinator.clear();
    _transitionTo(
      TrainerSessionPhase.sessionCompleted,
      reason: 'session completion committed',
    );
    appLogD('trainer', 'session completion committed');
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
    _sessionTracker.markStatsPersisted();
  }

  Future<void> _startNextCardCore() async {
    if (_stopRequested ||
        _disposeRequested ||
        !_isTrainingLifecycleActive) {
      return;
    }
    if (_sessionTracker.reachedLimit) {
      await _handleSessionLimitReached();
      return;
    }
    if (!_progressManager.hasRemainingCards) {
      await _completeSessionCore(reason: SessionCompletionReason.noCards);
      return;
    }

    _debugForcedMode = _settingsRepository.readDebugForcedMode();
    _debugForcedFamilyKey = _settingsRepository.readDebugForcedFamilyKey();
    final forcedMode = _parseMode(_debugForcedMode);
    final forcedFamilyKey = _validForcedFamilyKey(_debugForcedFamilyKey);
    final scheduleResult = await _taskScheduler.scheduleNext(
      progressManager: _progressManager,
      language: _currentLanguage(),
      profile: _currentProfile(),
      premiumPronunciationEnabled: _premiumPronunciationEnabled,
      forcedMode: forcedMode,
      forcedFamilyKey: forcedFamilyKey,
    );
    if (_shouldStop) return;
    if (scheduleResult is TaskScheduleFinished) {
      await _completeSessionCore(
        reason: SessionCompletionReason.schedulerFinished,
      );
      return;
    }
    if (scheduleResult is TaskSchedulePaused) {
      _errorMessage = scheduleResult.errorMessage;
      await _pauseTrainingCore();
      return;
    }
    if (scheduleResult is! TaskScheduleReady) {
      return;
    }

    final card = _taskCardFlow.resolveDynamicCard(scheduleResult.card);
    final hintText = _taskCardFlow.resolveHintText(
      card: card,
      mode: scheduleResult.mode,
      consecutiveCorrect: _progressManager
          .progressFor(card.progressId)
          .consecutiveCorrect,
      hintVisibleUntilCorrectStreak: _progressManager
          .hintVisibleUntilCorrectStreak(card.family),
    );

    _services.soundWave.reset();
    _errorMessage = null;
    if (_phase != TrainerSessionPhase.starting) {
      _transitionTo(
        TrainerSessionPhase.transitioning,
        reason: 'starting next card',
      );
    }
    final runtime = _createRuntime(
      card: card,
      mode: scheduleResult.mode,
      hintText: hintText,
    );
    try {
      final handle = await _runtimeCoordinator.attach(runtime);
      if (!_runtimeCoordinator.isCurrent(handle) || _shouldStop) return;
      _transitionTo(TrainerSessionPhase.active, reason: 'runtime started');
    } catch (error, stackTrace) {
      appLogE('trainer', 'runtime start failed', error: error, st: stackTrace);
      await _runtimeCoordinator.disposeRuntime(clearState: true);
      _errorMessage = 'Unable to start the exercise: $error';
      _transitionTo(TrainerSessionPhase.paused, reason: 'runtime start failed');
    }
  }

  TaskRuntime _createRuntime({
    required ExerciseCard card,
    required ExerciseMode mode,
    required String? hintText,
  }) {
    final cardDuration = card.family.defaultDuration;
    final profile = _appDefinition.profileOf(card.language);
    switch (mode) {
      case ExerciseMode.speak:
        return SpeakRuntime(
          card: card,
          profile: profile,
          tokenizer: _appDefinition.tokenizerOf(card.language),
          speechService: _services.speech,
          soundWaveService: _services.soundWave,
          cardTimer: _services.timer,
          cardDuration: cardDuration,
          hintText: hintText,
        );
      case ExerciseMode.chooseFromPrompt:
        return ChoiceRuntime(
          mode: mode,
          card: card,
          spec: _optionShuffler.shuffleChoice(card.chooseFromPrompt!),
          cardDuration: cardDuration,
          cardTimer: _services.timer,
        );
      case ExerciseMode.chooseFromAnswer:
        return ChoiceRuntime(
          mode: mode,
          card: card,
          spec: _optionShuffler.shuffleChoice(card.chooseFromAnswer!),
          cardDuration: cardDuration,
          cardTimer: _services.timer,
        );
      case ExerciseMode.listenAndChoose:
        return ListenAndChooseRuntime(
          card: card,
          spec: _optionShuffler.shuffleListening(card.listenAndChoose!),
          cardDuration: cardDuration,
          cardTimer: _services.timer,
          ttsService: _services.tts,
          locale: profile.locale,
          voiceId: _settingsRepository.readTtsVoiceId(card.language),
        );
      case ExerciseMode.reviewPronunciation:
        return ReviewPronunciationRuntime(
          card: card,
          spec: card.reviewPronunciation!,
          locale: profile.locale,
          audioRecorder: _services.audioRecorder,
          soundWaveService: _services.soundWave,
          azureSpeechService: _services.azure,
        );
    }
  }

  void _handleRuntimeEvent(RuntimeEventEnvelope envelope) {
    if (_disposed || _disposeRequested) {
      return;
    }
    unawaited(
      _enqueueRuntimeCallback(
        name: 'runtime event',
        generation: envelope.generation,
        operation: () => _handleRuntimeEventCore(envelope),
      ),
    );
  }

  Future<void> _handleRuntimeEventCore(RuntimeEventEnvelope envelope) async {
    final handle = _runtimeCoordinator.currentHandle;
    if (handle == null || handle.generation != envelope.generation) return;
    final event = envelope.event;
    if (event is TaskError) {
      _errorMessage = event.message;
      if (event.shouldPause) {
        await _pauseTrainingCore();
      } else {
        _syncState();
      }
      return;
    }
    if (event is TaskCompleted) {
      await _completeCurrentTaskCore(
        event.outcome,
        generation: envelope.generation,
      );
    }
  }

  Future<void> _completeCurrentTaskCore(
    TrainingOutcome outcome, {
    bool simulatedUserInteraction = false,
    int? generation,
  }) async {
    if (_phase != TrainerSessionPhase.active) return;
    final handle = _runtimeCoordinator.currentHandle;
    if (handle == null ||
        (generation != null && handle.generation != generation)) {
      return;
    }
    _transitionTo(
      TrainerSessionPhase.transitioning,
      reason: 'task completion claimed',
    );
    final completion = _runtimeCoordinator.takeCurrentForCompletion();
    if (completion == null) return;
    final taskState = completion.taskState;
    await _runtimeCoordinator.detach(
      handle: completion.handle,
      clearState: true,
    );
    if (_shouldStop) return;
    final progressUpdate = await _taskProgressRecorder.record(
      taskState: taskState,
      outcome: outcome,
      language: _currentLanguage(),
    );
    if (_shouldStop) return;
    if (progressUpdate.affectsProgress && progressUpdate.learned) {
      await _queueCelebration(taskState);
      if (_shouldStop) return;
    }

    final feedbackHold = _feedbackCoordinator.show(
      outcome,
      holdDuration: _feedbackHoldDuration(taskState, outcome),
    );

    _silentDetector.record(
      interacted:
          simulatedUserInteraction ||
          _runtimeCoordinator.taskHadUserInteraction,
      affectsProgress: progressUpdate.affectsProgress,
    );
    if (_silentDetector.shouldStop) {
      await _stopTrainingCore();
      _onAutoStop();
      return;
    }

    await feedbackHold;
    if (_stopRequested ||
        _disposed ||
        _disposeRequested ||
        _pendingCelebration != null ||
        !_isTrainingLifecycleActive) {
      return;
    }
    await _startNextCardCore();
  }

  Duration? _feedbackHoldDuration(
    TaskState taskState,
    TrainingOutcome outcome,
  ) {
    if (taskState is SpeakState && outcome == TrainingOutcome.correct) {
      return _fastSpeechCorrectFeedbackDuration;
    }
    return null;
  }

  Future<void> _queueCelebration(TaskState taskState) async {
    final nextCounter = _settingsRepository.readCelebrationCounter() + 1;
    await _settingsRepository.setCelebrationCounter(nextCounter);
    if (_shouldStop) return;
    _celebrationEventId += 1;
    _pendingCelebration = TrainingCelebration(
      eventId: _celebrationEventId,
      counter: nextCounter,
      masteredText: taskState.celebrationText,
      modeLabel: taskState.mode.label,
      categoryLabel: taskState.family.label,
    );
    _syncState();
  }

  Future<void> _pauseTrainingCore() async {
    if (_phase == TrainerSessionPhase.active) {
      _transitionTo(TrainerSessionPhase.transitioning, reason: 'pause requested');
    }
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    _transitionTo(TrainerSessionPhase.paused, reason: 'training paused');
    await _services.keepAwake.setEnabled(false);
  }

  void _transitionTo(
    TrainerSessionPhase next, {
    required String reason,
    bool publish = true,
  }) {
    final previous = _phase;
    if (previous == next) return;
    if (!_isAllowedTransition(previous, next)) {
      final error = StateError(
        'Invalid trainer phase transition: $previous -> $next ($reason)',
      );
      appLogE('trainer', error.message.toString(), error: error);
      assert(() {
        throw error;
      }());
      throw error;
    }
    _phase = next;
    appLogD('trainer', 'phase ${previous.name} -> ${next.name}: $reason');
    if (publish) _syncState();
  }

  bool _isAllowedTransition(TrainerSessionPhase from, TrainerSessionPhase to) =>
      switch (from) {
        TrainerSessionPhase.idle =>
          to == TrainerSessionPhase.starting ||
              to == TrainerSessionPhase.disposed,
        TrainerSessionPhase.starting =>
          to == TrainerSessionPhase.active ||
              to == TrainerSessionPhase.paused ||
              to == TrainerSessionPhase.stopping ||
              to == TrainerSessionPhase.sessionCompleted,
        TrainerSessionPhase.active =>
          to == TrainerSessionPhase.transitioning ||
              to == TrainerSessionPhase.paused ||
              to == TrainerSessionPhase.stopping,
        TrainerSessionPhase.transitioning =>
          to == TrainerSessionPhase.active ||
              to == TrainerSessionPhase.sessionCompleted ||
              to == TrainerSessionPhase.paused ||
              to == TrainerSessionPhase.stopping,
        TrainerSessionPhase.paused =>
          to == TrainerSessionPhase.starting ||
              to == TrainerSessionPhase.stopping ||
              to == TrainerSessionPhase.disposed,
        TrainerSessionPhase.sessionCompleted =>
          to == TrainerSessionPhase.starting ||
              to == TrainerSessionPhase.stopping ||
              to == TrainerSessionPhase.disposed,
        TrainerSessionPhase.stopping =>
          to == TrainerSessionPhase.idle || to == TrainerSessionPhase.disposed,
        TrainerSessionPhase.disposed => false,
      };

  Future<T> _enqueueCommand<T>({
    required String name,
    required Future<T> Function() operation,
    required TrainerCommandFailurePolicy failurePolicy,
    bool allowWhenStopRequested = false,
    bool allowWhenDisposeRequested = false,
  }) {
    if (_disposeRequested && !allowWhenDisposeRequested) {
      return Future<T>.value();
    }
    if (_stopRequested && !allowWhenStopRequested) {
      return Future<T>.value();
    }
    return _operations.enqueue(() async {
      appLogD('trainer', 'command started: $name');
      try {
        final result = await operation();
        appLogD('trainer', 'command completed: $name');
        return result;
      } catch (error, stackTrace) {
        appLogE(
          'trainer',
          'command failed: $name',
          error: error,
          st: stackTrace,
        );
        await _recoverFromCommandFailure(
          name: name,
          error: error,
          policy: failurePolicy,
        );
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<void> _recoverFromCommandFailure({
    required String name,
    required Object error,
    required TrainerCommandFailurePolicy policy,
  }) async {
    appLogD('trainer', 'command recovery policy=${policy.name}: $name');
    if (_disposed || policy == TrainerCommandFailurePolicy.reportOnly) return;
    if (policy == TrainerCommandFailurePolicy.finalDispose) {
      if (_phase != TrainerSessionPhase.disposed) {
        _disposed = true;
        _transitionTo(TrainerSessionPhase.disposed, reason: 'failed final disposal');
      }
      return;
    }
    if (policy == TrainerCommandFailurePolicy.normalizeToIdle) {
      if (_phase == TrainerSessionPhase.stopping) {
        _transitionTo(TrainerSessionPhase.idle, reason: 'failed stop normalized');
      }
      if (!_disposeRequested) _stopRequested = false;
      return;
    }
    _runtimeCoordinator.requestCancellation();
    try {
      await _runtimeCoordinator.disposeRuntime(clearState: true);
    } catch (cleanupError, cleanupStackTrace) {
      appLogE(
        'trainer',
        'runtime cleanup failed after $name',
        error: cleanupError,
        st: cleanupStackTrace,
      );
    }
    try {
      await _services.keepAwake.setEnabled(false);
    } catch (cleanupError, cleanupStackTrace) {
      appLogE(
        'trainer',
        'keep-awake cleanup failed after $name',
        error: cleanupError,
        st: cleanupStackTrace,
      );
    }
    _errorMessage = 'Unable to continue training: $error';
    if (_phase == TrainerSessionPhase.active) {
      _transitionTo(TrainerSessionPhase.transitioning, reason: 'command failed: $name');
    }
    if (_phase != TrainerSessionPhase.paused &&
        _phase != TrainerSessionPhase.idle &&
        _phase != TrainerSessionPhase.disposed) {
      _transitionTo(
        TrainerSessionPhase.paused,
        reason: 'command failed: $name',
      );
    } else if (_phase == TrainerSessionPhase.paused) {
      _syncState();
    }
  }

  Future<void> _enqueueRuntimeCallback({
    required String name,
    required int generation,
    required Future<void> Function() operation,
  }) async {
    await _operations.enqueue(() async {
      final handle = _runtimeCoordinator.currentHandle;
      if (_shouldStop || handle == null || handle.generation != generation) {
        return;
      }
      try {
        await operation();
      } catch (error, stackTrace) {
        appLogE(
          'trainer',
          'runtime callback failed: $name',
          error: error,
          st: stackTrace,
        );
        await _recoverFromCommandFailure(
          name: 'runtime callback $name',
          error: error,
          policy: TrainerCommandFailurePolicy.pauseTraining,
        );
      }
    });
  }

  ExerciseMode? _parseMode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    for (final mode in ExerciseMode.values) {
      if (mode.name == raw.trim()) {
        return mode;
      }
    }
    return null;
  }

  String? _validForcedFamilyKey(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final key = raw.trim();
    final exists = _progressManager.cards.any(
      (card) => card.family.storageKey == key,
    );
    return exists ? key : null;
  }
}

enum SessionCompletionReason { limitReached, noCards, schedulerFinished }

enum TrainerCommandFailurePolicy {
  pauseTraining,
  normalizeToIdle,
  finalDispose,
  reportOnly,
}
