import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../data/card_progress.dart';
import '../data/number_cards.dart';
import '../data/phrase_templates.dart';
import 'language_router.dart';
import 'learning_language.dart';
import 'repositories.dart';
import 'runtimes/multiple_choice_runtime.dart';
import 'runtimes/number_pronunciation_runtime.dart';
import 'runtimes/phrase_pronunciation_runtime.dart';
import 'session_helpers.dart';
import 'task_registry.dart';
import 'task_runtime.dart';
import 'task_state.dart';
import 'tasks/number_pronunciation_task.dart';
import 'tasks/number_to_word_task.dart';
import 'training_outcome.dart';
import 'training_services.dart';
import 'training_state.dart';
import 'training_task.dart';

class TrainingSession {
  TrainingSession({
    required SettingsRepositoryBase settingsRepository,
    required ProgressRepositoryBase progressRepository,
    TrainingServices? services,
    PhraseTemplates? phraseTemplates,
    TaskRegistry? taskRegistry,
    void Function()? onStateChanged,
  })  : _settingsRepository = settingsRepository,
        _progressRepository = progressRepository,
        _services = services ?? TrainingServices.defaults(),
        _onStateChanged = onStateChanged ?? _noop {
    final resolvedTemplates = phraseTemplates ?? PhraseTemplates(Random());
    _languageRouter = LanguageRouter(
      settingsRepository: _settingsRepository,
      phraseTemplates: resolvedTemplates,
    );
    _taskRegistry = taskRegistry ?? _buildDefaultRegistry();
    _internetGate = InternetGate(
      checker: _services.internet,
      cache: _internetCheckCache,
    );
    _refreshCardsIfNeeded();
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    _syncState();
  }

  static void _noop() {}

  static const int _numberPronunciationWeight = 70;
  static const int _numberToWordWeight = 15;
  static const int _wordToNumberWeight = 15;
  static const int _phrasePronunciationWeight = 5;
  static const Duration _internetCheckCache = Duration(seconds: 10);
  static const Duration _feedbackDuration = Duration(milliseconds: 1500);

  final Random _random = Random();
  final TrainingServices _services;
  final SettingsRepositoryBase _settingsRepository;
  final ProgressRepositoryBase _progressRepository;
  final void Function() _onStateChanged;
  late final LanguageRouter _languageRouter;
  late final TaskRegistry _taskRegistry;
  late final InternetGate _internetGate;

  Map<int, NumberPronunciationTask> _cardsById = {};
  List<int> _cardIds = [];
  LearningLanguage? _cardsLanguage;

  Map<int, CardProgress> _progressById = {};
  List<int> _pool = [];

  TaskRuntime? _runtime;
  StreamSubscription<TaskEvent>? _runtimeEvents;
  StreamSubscription<TaskState>? _runtimeStates;
  TaskState? _currentTaskState;

  int? _currentPoolIndex;

  bool _premiumPronunciationEnabled = false;
  TrainingTaskKind? _debugForcedTaskKind;

  TrainerStatus _status = TrainerStatus.idle;
  bool _speechReady = false;
  String? _errorMessage;
  TrainingFeedback? _feedback;
  Timer? _feedbackTimer;
  Completer<void>? _feedbackCompleter;

  final SilentDetector _silentDetector = SilentDetector();
  final StreakTracker _streakTracker = StreakTracker();
  bool _taskHadUserInteraction = false;

  bool _disposed = false;

  TrainingState _state = TrainingState.initial();
  TrainingState get state => _state;

  Stream<List<double>> get soundStream => _services.soundWave.stream;

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

  Future<void> initialize() async {
    await _loadProgress();
    _syncState();
  }

  Future<void> retryInitSpeech() async {
    final runtime = _runtime;
    if (runtime is NumberPronunciationRuntime) {
      await runtime.handleAction(const RetrySpeechInitAction());
      return;
    }
    await _initSpeechDirect();
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
    await _internetGate.refresh(force: true);
    if (_pool.isEmpty) {
      _status = TrainerStatus.finished;
      unawaited(_setKeepAwake(false));
      _syncState();
      return;
    }

    _errorMessage = null;
    _status = TrainerStatus.running;
    _silentDetector.reset();
    _streakTracker.reset();
    _taskHadUserInteraction = false;
    _syncState();
    unawaited(_setKeepAwake(true));
    await _startNextCard();
  }

  Future<void> stopTraining() async {
    _clearFeedback();
    await _disposeRuntime(clearState: true);
    _services.soundWave.reset();
    _status = TrainerStatus.idle;
    _errorMessage = null;
    _currentPoolIndex = null;
    _currentTaskState = null;
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    _silentDetector.reset();
    _streakTracker.reset();
    _taskHadUserInteraction = false;
    _syncState();
    unawaited(_setKeepAwake(false));
  }

  Future<void> pauseForOverlay() async {
    await _disposeRuntime(clearState: true);
    _status = TrainerStatus.idle;
    await _setKeepAwake(false);
    _syncState();
  }

  Future<void> restoreAfterOverlay() async {
    await _loadProgress();
    _premiumPronunciationEnabled =
        _settingsRepository.readPremiumPronunciationEnabled();
    _debugForcedTaskKind = _readDebugForcedTaskKind();
    _currentPoolIndex = null;
    _currentTaskState = null;
    _silentDetector.reset();
    _taskHadUserInteraction = false;
    _status = TrainerStatus.idle;
    await _setKeepAwake(false);
    _syncState();
  }

  Future<void> handleAction(TaskAction action) async {
    final runtime = _runtime;
    if (runtime == null) return;
    await runtime.handleAction(action);
  }

  Future<void> completeCurrentTaskWithOutcome(TrainingOutcome outcome) async {
    if (_currentTaskState == null) return;
    await _handleTaskCompleted(outcome);
  }

  void _syncState() {
    if (_disposed) return;
    _state = TrainingState(
      status: _status,
      speechReady: _speechReady,
      errorMessage: _errorMessage,
      feedback: _feedback,
      currentTask: _currentTaskState,
    );
    _onStateChanged();
  }

  void dispose() {
    _disposed = true;
    _clearFeedback();
    unawaited(_disposeRuntime(clearState: true));
    _services.dispose();
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

  Future<void> _initSpeechDirect() async {
    final result = await _services.speech.initialize(
      onError: _logSpeechError,
      onStatus: (_) {},
    );
    _speechReady = result.ready;
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
      TrainingTaskKind.phrasePronunciation: _buildPhrasePronunciationRuntime,
    });
  }

  void _handleSpeechReady(bool ready, String? errorMessage) {
    _speechReady = ready;
    if (ready) {
      _errorMessage = null;
    } else if (errorMessage != null) {
      _errorMessage = errorMessage;
    }
    _syncState();
  }

  TaskRuntime _buildNumberToWordRuntime(TaskBuildContext context) {
    final correct = context.toWords(context.card.id);
    final options = <String>{correct};

    while (options.length < numberToWordOptionCount) {
      final candidateId = context.cardIds[context.random.nextInt(context.cardIds.length)];
      if (candidateId == context.card.id) continue;
      try {
        final option = context.toWords(candidateId);
        options.add(option);
      } catch (_) {
        // Skip invalid conversions and try another number.
      }
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceRuntime(
      kind: TrainingTaskKind.numberToWord,
      taskId: _generateNumberToWordTaskId(context.card.id),
      numberValue: context.card.id,
      prompt: context.card.prompt,
      correctOption: correct,
      options: shuffled,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
    );
  }

  TaskRuntime _buildWordToNumberRuntime(TaskBuildContext context) {
    final correctWord = context.toWords(context.card.id);
    final correctOption = context.card.id.toString();
    final options = <String>{correctOption};

    while (options.length < numberToWordOptionCount) {
      final candidateId = context.cardIds[context.random.nextInt(context.cardIds.length)];
      if (candidateId == context.card.id) continue;
      options.add(candidateId.toString());
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceRuntime(
      kind: TrainingTaskKind.wordToNumber,
      taskId: _generateWordToNumberTaskId(context.card.id),
      numberValue: context.card.id,
      prompt: correctWord,
      correctOption: correctOption,
      options: shuffled,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
    );
  }

  TaskRuntime _buildPhrasePronunciationRuntime(TaskBuildContext context) {
    final template = _languageRouter.pickTemplate(
      context.card.id,
      language: context.language,
    );
    if (template == null) {
      return _buildFallbackPronunciationRuntime(context);
    }
    final task = template.toTask(
      value: context.card.id,
      taskId: _generatePhraseTaskId(context.card.id, template.id),
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

  int _generateNumberToWordTaskId(int numberValue) {
    return numberValue * 1000 + 500;
  }

  int _generateWordToNumberTaskId(int numberValue) {
    return numberValue * 1000 + 501;
  }

  int _generatePhraseTaskId(int numberValue, int templateId) {
    return numberValue * 1000 + templateId;
  }

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
    await _internetGate.refresh();
    if (requirePhrase && !_internetGate.hasInternet) {
      _errorMessage =
          'Premium pronunciation requires an internet connection.';
      await _pauseTraining();
      return;
    }
    final allowPhrase =
        (_premiumPronunciationEnabled && _internetGate.hasInternet) ||
            requirePhrase;
    final poolIndex = _pickPoolIndex(
      language: language,
      requirePhrase: requirePhrase,
    );
    if (poolIndex == null) {
      if (requirePhrase) {
        _errorMessage =
            'Phrase pronunciation tasks are not available for the selected language.';
        await _pauseTraining();
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
      await _pauseTraining();
      return;
    }
    final taskKind =
        forcedTaskKind ?? _pickTaskKind(canUsePhrase: canUsePhrase);

    _currentPoolIndex = poolIndex;
    _taskHadUserInteraction = false;
    _services.soundWave.reset();

    final hintText = _resolveHintText(card, taskKind);
    final context = TaskBuildContext(
      card: card,
      language: language,
      cardIds: _cardIds,
      toWords: _languageRouter.numberWordsConverter(language),
      cardDuration: _resolveCardDuration(),
      languageRouter: _languageRouter,
      random: _random,
      services: _services,
      hintText: hintText,
    );

    final runtime = _taskRegistry.create(taskKind, context);
    await _attachRuntime(runtime);
  }

  Future<void> _attachRuntime(TaskRuntime runtime) async {
    await _disposeRuntime(clearState: false);
    _runtime = runtime;
    _runtimeEvents = runtime.events.listen(_handleTaskEvent);
    _runtimeStates = runtime.states.listen((state) {
      _currentTaskState = state;
      if (state is NumberPronunciationState) {
        _speechReady = state.speechReady;
      }
      _syncState();
    });
    _currentTaskState = runtime.state;
    if (_currentTaskState is NumberPronunciationState) {
      _speechReady = (_currentTaskState as NumberPronunciationState).speechReady;
    }
    final resolvedKind = runtime.state.kind;
    _status = resolvedKind == TrainingTaskKind.phrasePronunciation
        ? TrainerStatus.waitingRecording
        : TrainerStatus.running;
    _errorMessage = null;
    _syncState();
    await runtime.start();
  }

  Future<void> _disposeRuntime({required bool clearState}) async {
    await _runtimeEvents?.cancel();
    await _runtimeStates?.cancel();
    _runtimeEvents = null;
    _runtimeStates = null;
    final runtime = _runtime;
    _runtime = null;
    if (runtime != null) {
      await runtime.dispose();
    }
    if (clearState) {
      _currentTaskState = null;
    }
  }

  void _handleTaskEvent(TaskEvent event) {
    if (_disposed) return;
    if (event is TaskUserInteracted) {
      _taskHadUserInteraction = true;
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

  Future<void> _handleTaskCompleted(TrainingOutcome outcome) async {
    final taskState = _currentTaskState;
    if (taskState == null) return;
    await _disposeRuntime(clearState: false);

    final affectsProgress =
        taskState.affectsProgress && outcome != TrainingOutcome.ignore;
    if (affectsProgress) {
      final isCorrect = outcome == TrainingOutcome.success;
      _streakTracker.record(isCorrect);
      await _updateProgress(
        progressKey: taskState.numberValue,
        isCorrect: isCorrect,
      );
    }

    final feedbackHold = _showFeedback(outcome: outcome);

    _silentDetector.record(
      interacted: _taskHadUserInteraction,
      affectsProgress: affectsProgress,
    );
    if (_silentDetector.shouldPause) {
      await _pauseTraining();
      return;
    }

    if (_status == TrainerStatus.waitingRecording) {
      _status = TrainerStatus.running;
    }

    await feedbackHold;
    if (_disposed) return;
    if (_status != TrainerStatus.running &&
        _status != TrainerStatus.waitingRecording) {
      return;
    }

    await _startNextCard();
  }

  Future<void> _updateProgress({
    required int progressKey,
    required bool isCorrect,
  }) async {
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

  Future<void> _showFeedback({required TrainingOutcome outcome}) {
    _feedbackTimer?.cancel();
    _feedbackCompleter?.complete();
    _feedbackCompleter = null;
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

    final completer = Completer<void>();
    _feedbackCompleter = completer;
    _feedbackTimer = Timer(_feedbackDuration, _clearFeedback);

    final shouldHold = type == TrainingFeedbackType.correct ||
        type == TrainingFeedbackType.wrong ||
        type == TrainingFeedbackType.timeout;
    if (!shouldHold) {
      return Future.value();
    }
    return completer.future;
  }

  void _clearFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _feedback = null;
    _syncState();
    _feedbackCompleter?.complete();
    _feedbackCompleter = null;
  }

  Future<void> _pauseTraining() async {
    await _disposeRuntime(clearState: false);
    _status = TrainerStatus.paused;
    _syncState();
    unawaited(_setKeepAwake(false));
  }

  Future<void> _setKeepAwake(bool enabled) async {
    await _services.keepAwake.setEnabled(enabled);
  }
}
