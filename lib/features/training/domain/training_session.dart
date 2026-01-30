import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../data/phrase_templates.dart';
import 'feedback_coordinator.dart';
import 'language_router.dart';
import 'learning_language.dart';
import 'progress_manager.dart';
import 'repositories.dart';
import 'runtimes/listening_numbers_runtime.dart';
import 'runtimes/multiple_choice_runtime.dart';
import 'runtimes/number_pronunciation_runtime.dart';
import 'runtimes/phrase_pronunciation_runtime.dart';
import 'runtime_coordinator.dart';
import 'session_helpers.dart';
import 'task_availability.dart';
import 'task_registry.dart';
import 'task_runtime.dart';
import 'task_scheduler.dart';
import 'tasks/number_pronunciation_task.dart';
import 'tasks/number_to_word_task.dart';
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
    PhraseTemplates? phraseTemplates,
    TaskRegistry? taskRegistry,
    void Function()? onStateChanged,
    void Function()? onAutoStop,
  })  : _settingsRepository = settingsRepository,
        _progressRepository = progressRepository,
        _services = services ?? TrainingServices.defaults(),
        _onStateChanged = onStateChanged ?? _noop,
        _onAutoStop = onAutoStop ?? _noop {
    final resolvedTemplates = phraseTemplates ?? PhraseTemplates(Random());
    _languageRouter = LanguageRouter(
      settingsRepository: _settingsRepository,
      phraseTemplates: resolvedTemplates,
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
      random: _random,
    );
    _feedbackCoordinator = FeedbackCoordinator(onChanged: _syncState);
    _runtimeCoordinator = RuntimeCoordinator(
      onChanged: _syncState,
      onEvent: _handleRuntimeEvent,
    );
    _refreshCardsIfNeeded();
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    _syncState();
  }

  static void _noop() {}

  final Random _random = Random();
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

  bool _premiumPronunciationEnabled = false;
  TrainingTaskKind? _debugForcedTaskKind;

  String? _errorMessage;

  final SilentDetector _silentDetector = SilentDetector();
  final StreakTracker _streakTracker = StreakTracker();

  bool _disposed = false;
  bool _trainingActive = false;

  TrainingState _state = TrainingState.initial();
  TrainingState get state => _state;

  Stream<List<double>> get soundStream => _services.soundWave.stream;

  int get totalCards => _progressManager.totalCards;
  int get learnedCount => _progressManager.learnedCount;
  int get remainingCount => _progressManager.remainingCount;
  bool get hasRemainingCards => _progressManager.hasRemainingCards;

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

    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
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
    await _startNextCard();
  }

  Future<void> stopTraining() async {
    _feedbackCoordinator.clear();
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    _services.soundWave.reset();
    _trainingActive = false;
    _errorMessage = null;
    _progressManager.resetSelection();
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    _silentDetector.reset();
    _streakTracker.reset();
    _runtimeCoordinator.resetInteraction();
    _syncState();
    unawaited(_setKeepAwake(false));
  }

  Future<void> pauseForOverlay() async {
    await _runtimeCoordinator.disposeRuntime(clearState: true);
    _trainingActive = false;
    await _setKeepAwake(false);
    _syncState();
  }

  Future<void> restoreAfterOverlay() async {
    await _loadProgress();
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    _progressManager.resetSelection();
    await _runtimeCoordinator.disposeRuntime(clearState: true);
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

  void _syncState() {
    if (_disposed) return;
    _state = TrainingState(
      speechReady: _runtimeCoordinator.speechReady,
      errorMessage: _errorMessage,
      feedback: _feedbackCoordinator.feedback,
      currentTask: _runtimeCoordinator.currentTask,
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
    if (!kDebugMode) return;
    debugPrint('Speech error during init: ${error.errorMsg}');
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

  Duration _resolveCardDuration() {
    final seconds = _settingsRepository.readAnswerDurationSeconds();
    return Duration(seconds: seconds);
  }

  String? _resolveHintText(NumberPronunciationTask card, TrainingTaskKind kind) {
    if (kind != TrainingTaskKind.numberPronunciation) return null;
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
      TrainingTaskKind.numberPronunciation: (context) {
        return NumberPronunciationRuntime(
          task: context.card,
          speechService: context.services.speech,
          soundWaveService: context.services.soundWave,
          cardTimer: context.services.timer,
          cardDuration: context.cardDuration,
          hintText: context.hintText,
          onSpeechReady: _handleSpeechReady,
        );
      },
      TrainingTaskKind.numberToWord: _buildNumberToWordRuntime,
      TrainingTaskKind.wordToNumber: _buildWordToNumberRuntime,
      TrainingTaskKind.listeningNumbers: _buildListeningNumbersRuntime,
      TrainingTaskKind.phrasePronunciation: _buildPhrasePronunciationRuntime,
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

  TaskRuntime _buildNumberToWordRuntime(TaskBuildContext context) {
    final correct = context.toWords(context.card.numberValue);
    final options = <String>{correct};
    final candidateIds = _candidateIdsFor(context);

    while (options.length < numberToWordOptionCount) {
      final candidateId =
          candidateIds[context.random.nextInt(candidateIds.length)];
      final candidateValue = candidateId.number!;
      if (candidateValue == context.card.numberValue) continue;
      try {
        final option = context.toWords(candidateValue);
        options.add(option);
      } catch (_) {
        // Skip invalid conversions and try another number.
      }
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceRuntime(
      kind: TrainingTaskKind.numberToWord,
      taskId: context.card.id,
      numberValue: context.card.numberValue,
      prompt: context.card.prompt,
      correctOption: correct,
      options: shuffled,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
    );
  }

  TaskRuntime _buildWordToNumberRuntime(TaskBuildContext context) {
    final correctWord = context.toWords(context.card.numberValue);
    final correctOption = context.card.numberValue.toString();
    final options = <String>{correctOption};
    final candidateIds = _candidateIdsFor(context);

    while (options.length < numberToWordOptionCount) {
      final candidateId =
          candidateIds[context.random.nextInt(candidateIds.length)];
      final candidateValue = candidateId.number!;
      if (candidateValue == context.card.numberValue) continue;
      options.add(candidateValue.toString());
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceRuntime(
      kind: TrainingTaskKind.wordToNumber,
      taskId: context.card.id,
      numberValue: context.card.numberValue,
      prompt: correctWord,
      correctOption: correctOption,
      options: shuffled,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
    );
  }

  TaskRuntime _buildListeningNumbersRuntime(TaskBuildContext context) {
    final correctOption = context.card.numberValue.toString();
    final options = <String>{correctOption};
    final candidateIds = _candidateIdsFor(context);

    while (options.length < numberToWordOptionCount) {
      final candidateId =
          candidateIds[context.random.nextInt(candidateIds.length)];
      final candidateValue = candidateId.number!;
      if (candidateValue == context.card.numberValue) continue;
      options.add(candidateValue.toString());
    }

    final shuffled = options.toList()..shuffle(context.random);
    String speechText;
    try {
      speechText = context.toWords(context.card.numberValue);
    } catch (_) {
      speechText = correctOption;
    }

    final voiceId = _settingsRepository.readTtsVoiceId(context.language);
    return ListeningNumbersRuntime(
      taskId: context.card.id,
      numberValue: context.card.numberValue,
      options: shuffled,
      speechText: speechText,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
      ttsService: context.services.tts,
      locale: context.language.locale,
      voiceId: voiceId,
    );
  }

  TaskRuntime _buildPhrasePronunciationRuntime(TaskBuildContext context) {
    final template = _languageRouter.pickTemplate(
      context.card.numberValue,
      language: context.language,
    );
    if (template == null) {
      return _buildFallbackPronunciationRuntime(context);
    }
    final task = template.toTask(
      value: context.card.numberValue,
      taskId: context.card.id,
    );
    return PhrasePronunciationRuntime(
      task: task,
      language: context.language,
      audioRecorder: context.services.audioRecorder,
      soundWaveService: context.services.soundWave,
      azureSpeechService: context.services.azure,
    );
  }

  TaskRuntime _buildFallbackPronunciationRuntime(TaskBuildContext context) {
    final hintText =
        context.hintText ?? _resolveHintText(context.card, TrainingTaskKind.numberPronunciation);
    return NumberPronunciationRuntime(
      task: context.card,
      speechService: context.services.speech,
      soundWaveService: context.services.soundWave,
      cardTimer: context.services.timer,
      cardDuration: context.cardDuration,
      hintText: hintText,
      onSpeechReady: _handleSpeechReady,
    );
  }

  Future<void> _startNextCard() async {
    if (!_trainingActive) {
      return;
    }
    if (!_progressManager.hasRemainingCards) {
      _trainingActive = false;
      unawaited(_setKeepAwake(false));
      _syncState();
      return;
    }

    final language = _currentLanguage();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    final scheduleResult = await _taskScheduler.scheduleNext(
      progressManager: _progressManager,
      language: language,
      premiumPronunciationEnabled: _premiumPronunciationEnabled,
      forcedTaskKind: _debugForcedTaskKind,
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

    final card = scheduleResult.card;
    final taskKind = scheduleResult.kind;

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

    final affectsProgress =
        taskState.affectsProgress && outcome != TrainingOutcome.ignore;
    if (affectsProgress) {
      final isCorrect = outcome == TrainingOutcome.success;
      _streakTracker.record(isCorrect);
      final progressResult = await _progressManager.updateProgress(
        progressKey: taskState.taskId,
        isCorrect: isCorrect,
        language: _currentLanguage(),
      );
      if (progressResult.learned && progressResult.poolEmpty) {
        _trainingActive = false;
        unawaited(_setKeepAwake(false));
        _syncState();
      }
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
    if (!_trainingActive) {
      return;
    }

    await _startNextCard();
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
