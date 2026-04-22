import 'dart:async';
import 'dart:math' as math;

import 'app_definition.dart';
import 'base_language_profile.dart';
import 'exercise_models.dart';
import 'feedback_coordinator.dart';
import 'progress_manager.dart';
import 'runtime_coordinator.dart';
import 'runtimes/choice_runtime.dart';
import 'runtimes/listen_and_choose_runtime.dart';
import 'runtimes/review_pronunciation_runtime.dart';
import 'runtimes/speak_runtime.dart';
import 'session_lifecycle_tracker.dart';
import 'session_progress_plan.dart';
import 'session_stats_recorder.dart';
import 'task_availability.dart';
import 'task_card_flow.dart';
import 'task_progress_recorder.dart';
import 'task_runtime.dart';
import 'task_scheduler.dart';
import 'trainer_repositories.dart';
import 'trainer_services.dart';
import 'trainer_state.dart';
import 'training/domain/learning_language.dart';

class TrainerSession {
  TrainerSession({
    required TrainingAppDefinition appDefinition,
    required SettingsRepositoryBase settingsRepository,
    required ProgressRepositoryBase progressRepository,
    TrainingServices? services,
    void Function()? onStateChanged,
  }) : _appDefinition = appDefinition,
       _settingsRepository = settingsRepository,
       _services = services ?? TrainingServices.defaults(),
       _onStateChanged = onStateChanged ?? _noop {
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
    _premiumPronunciationEnabled = _settingsRepository
        .readPremiumPronunciationEnabled();
    _syncState();
  }

  static void _noop() {}
  final TrainingAppDefinition _appDefinition;
  final SettingsRepositoryBase _settingsRepository;
  final TrainingServices _services;
  void Function() _onStateChanged;

  final math.Random _random = math.Random();
  final SessionLifecycleTracker _sessionTracker = SessionLifecycleTracker();
  final TaskCardFlow _taskCardFlow = const TaskCardFlow();
  late ProgressManager _progressManager;
  late TaskProgressRecorder _taskProgressRecorder;
  late FeedbackCoordinator _feedbackCoordinator;
  late RuntimeCoordinator _runtimeCoordinator;
  late TaskScheduler _taskScheduler;
  late SessionStatsRecorder _sessionStatsRecorder;

  bool _premiumPronunciationEnabled = false;
  String? _debugForcedMode;
  String? _debugForcedFamilyKey;
  bool _trainingActive = false;
  bool _disposed = false;
  String? _errorMessage;
  SessionStats? _sessionStats;
  TrainingCelebration? _pendingCelebration;
  int _celebrationEventId = 0;
  TrainingState _state = TrainingState.initial();

  TrainingState get state => _state;
  Stream<List<double>> get soundStream => _services.soundWave.stream;
  int get dailyGoalCards => _progressManager.dailySummary().targetToday;
  int get sessionCardsCompleted => _sessionTracker.cardsCompleted;
  int get sessionTargetCards => _sessionTracker.targetCards;

  set onStateChanged(void Function() callback) {
    _onStateChanged = callback;
  }

  Future<void> initialize() async {
    await _loadProgress();
    _syncState();
  }

  Future<void> retryInitSpeech() async {
    final runtime = _runtimeCoordinator.runtime;
    if (runtime is SpeakRuntime) {
      await runtime.handleAction(const RetrySpeechInitAction());
      return;
    }
    await _syncSpeechAvailability();
  }

  Future<void> startTraining() async {
    if (_trainingActive) {
      return;
    }
    _sessionStats = null;
    _pendingCelebration = null;
    _premiumPronunciationEnabled = _settingsRepository
        .readPremiumPronunciationEnabled();
    _debugForcedMode = _settingsRepository.readDebugForcedMode();
    _debugForcedFamilyKey = _settingsRepository.readDebugForcedFamilyKey();

    if (_progressManager.cardsLanguage != _currentLanguage()) {
      await _loadProgress();
    }
    await _taskScheduler.warmUpAvailability(
      language: _currentLanguage(),
      profile: _currentProfile(),
      premiumPronunciationEnabled: _premiumPronunciationEnabled,
    );
    if (!_progressManager.hasRemainingCards) {
      _trainingActive = false;
      _syncState();
      return;
    }
    _trainingActive = true;
    _runtimeCoordinator.resetInteraction();
    _errorMessage = null;
    _resetSessionCounters(targetCards: _initialSessionTargetCards());
    _syncState();
    await _services.keepAwake.setEnabled(true);
    await _startNextCard();
  }

  Future<void> continueSession() async {
    _resetSessionCounters(targetCards: dailyGoalCards);
    _sessionStats = null;
    _syncState();
    await _startNextCard();
  }

  Future<void> continueAfterCelebration() async {
    if (_pendingCelebration == null) {
      return;
    }
    _pendingCelebration = null;
    _syncState();
    if (!_trainingActive || _disposed) {
      return;
    }
    await _startNextCard();
  }

  Future<void> stopTraining() async {
    await _persistCurrentSessionIfNeeded();
    _feedbackCoordinator.clear();
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    _trainingActive = false;
    _errorMessage = null;
    _progressManager.resetSelection();
    _runtimeCoordinator.resetInteraction();
    _sessionStats = null;
    _pendingCelebration = null;
    _syncState();
    await _services.keepAwake.setEnabled(false);
  }

  Future<void> pauseTaskTimer() async {
    await _runtimeCoordinator.handleAction(const PauseTaskAction());
  }

  Future<void> resumeTaskTimer() async {
    await _runtimeCoordinator.handleAction(const ResumeTaskAction());
  }

  Future<void> handleAction(TaskAction action) async {
    await _runtimeCoordinator.handleAction(action);
  }

  Future<void> completeCurrentTaskWithOutcome(
    TrainingOutcome outcome, {
    bool simulatedUserInteraction = false,
  }) async {
    if (_runtimeCoordinator.currentTask == null) {
      return;
    }
    await _handleTaskCompleted(
      outcome,
      simulatedUserInteraction: simulatedUserInteraction,
    );
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _feedbackCoordinator.dispose();
    unawaited(
      _runtimeCoordinator
          .disposeRuntime(clearState: true)
          .whenComplete(_services.dispose),
    );
  }

  Future<void> _loadProgress() async {
    await _progressManager.loadProgress(_currentLanguage());
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
    );
    _onStateChanged();
  }

  Future<void> _syncSpeechAvailability() async {
    final result = await _services.speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    _runtimeCoordinator.updateSpeechReady(result.ready);
    _errorMessage = result.ready ? null : result.errorMessage;
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
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    await _services.keepAwake.setEnabled(false);
    _sessionStats = SessionStats(
      cardsCompleted: _sessionTracker.cardsCompleted,
      duration: elapsed,
      sessionsCompletedToday: todayStats.sessionsCompleted,
      cardsCompletedToday: dailySummary.completedToday,
      durationToday: todayStats.duration,
    );
    _state = TrainingState(
      errorMessage: null,
      feedback: null,
      currentTask: null,
      sessionStats: _sessionStats,
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
    _sessionTracker.markStatsPersisted();
  }

  Future<void> _startNextCard() async {
    if (!_trainingActive) {
      return;
    }
    if (_sessionTracker.reachedLimit) {
      await _handleSessionLimitReached();
      return;
    }
    if (!_progressManager.hasRemainingCards) {
      _trainingActive = false;
      await _services.keepAwake.setEnabled(false);
      _syncState();
      return;
    }

    _debugForcedMode = _settingsRepository.readDebugForcedMode();
    _debugForcedFamilyKey = _settingsRepository.readDebugForcedFamilyKey();
    final forcedMode = _parseMode(_debugForcedMode);
    final scheduleResult = await _taskScheduler.scheduleNext(
      progressManager: _progressManager,
      language: _currentLanguage(),
      profile: _currentProfile(),
      premiumPronunciationEnabled: _premiumPronunciationEnabled,
      forcedMode: forcedMode,
      forcedFamilyKey: _debugForcedFamilyKey,
    );
    if (scheduleResult is TaskScheduleFinished) {
      _trainingActive = false;
      await _services.keepAwake.setEnabled(false);
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
    final runtime = _createRuntime(
      card: card,
      mode: scheduleResult.mode,
      hintText: hintText,
    );
    await _runtimeCoordinator.attach(runtime);
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
          onSpeechReady: _handleSpeechReady,
        );
      case ExerciseMode.chooseFromPrompt:
        return ChoiceRuntime(
          mode: mode,
          card: card,
          spec: card.chooseFromPrompt!,
          cardDuration: cardDuration,
          cardTimer: _services.timer,
        );
      case ExerciseMode.chooseFromAnswer:
        return ChoiceRuntime(
          mode: mode,
          card: card,
          spec: card.chooseFromAnswer!,
          cardDuration: cardDuration,
          cardTimer: _services.timer,
        );
      case ExerciseMode.listenAndChoose:
        return ListenAndChooseRuntime(
          card: card,
          spec: card.listenAndChoose!,
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

  void _handleSpeechReady(bool ready, String? errorMessage) {
    _runtimeCoordinator.updateSpeechReady(ready);
    if (ready) {
      _errorMessage = null;
    } else if (errorMessage != null) {
      _errorMessage = errorMessage;
    }
    _syncState();
  }

  void _handleRuntimeEvent(TaskEvent event) {
    if (_disposed) {
      return;
    }
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
    if (taskState == null) {
      return;
    }
    await _runtimeCoordinator.disposeRuntime(clearState: false);
    final progressUpdate = await _taskProgressRecorder.record(
      taskState: taskState,
      outcome: outcome,
      language: _currentLanguage(),
    );
    if (progressUpdate.affectsProgress && progressUpdate.learned) {
      await _queueCelebration(taskState);
    }

    final feedbackHold = _feedbackCoordinator.show(outcome);
    if (!simulatedUserInteraction && !_runtimeCoordinator.taskHadUserInteraction) {
      // Preserve the old auto-stop extension point even though the new shell
      // does not yet simulate silent streak detection.
    }

    await feedbackHold;
    if (_disposed || _pendingCelebration != null || !_trainingActive) {
      return;
    }
    await _startNextCard();
  }

  Future<void> _queueCelebration(TaskState taskState) async {
    final nextCounter = _settingsRepository.readCelebrationCounter() + 1;
    await _settingsRepository.setCelebrationCounter(nextCounter);
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

  Future<void> _pauseTraining() async {
    await _runtimeCoordinator.disposeRuntime(clearState: false);
    _trainingActive = false;
    _syncState();
    await _services.keepAwake.setEnabled(false);
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
}
