import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'pronunciation_models.dart';
import 'repositories.dart';
import 'task_runtime.dart';
import 'task_state.dart';
import 'training_outcome.dart';
import 'training_services.dart';
import 'training_session.dart';
import 'training_state.dart';
import 'training_task.dart';

export 'task_runtime.dart'
    show
        TaskAction,
        SelectOptionAction,
        RepeatPromptAction,
        RetrySpeechInitAction,
        StartRecordingAction,
        StopRecordingAction,
        CancelRecordingAction,
        SendRecordingAction,
        CompleteReviewAction;
export 'task_state.dart'
    show
        TaskState,
        NumberPronunciationState,
        MultipleChoiceState,
        ListeningState,
        PhrasePronunciationState,
        PhraseFlow,
        TimerState;
export 'training_outcome.dart' show TrainingOutcome;
export 'training_state.dart';
export 'training_task.dart' show LearningMethod;

class TrainingController extends ChangeNotifier {
  TrainingController({
    required SettingsRepositoryBase settingsRepository,
    required ProgressRepositoryBase progressRepository,
    TrainingServices? services,
    stt.SpeechToText? speech,
    VoidCallback? onAutoStop,
  }) {
    _session = TrainingSession(
      settingsRepository: settingsRepository,
      progressRepository: progressRepository,
      services: services ?? TrainingServices.defaults(speech: speech),
      onStateChanged: _notify,
      onAutoStop: onAutoStop,
    );
  }

  late final TrainingSession _session;
  bool _disposed = false;

  TrainingState get state => _session.state;
  bool get speechReady => _session.state.speechReady;
  String? get errorMessage => _session.state.errorMessage;
  TrainingFeedback? get feedback => _session.state.feedback;
  String? get feedbackText => _session.state.feedback?.text;
  TrainingOutcome? get feedbackOutcome => _session.state.feedback?.outcome;
  TaskState? get currentTask => _session.state.currentTask;
  SessionStats? get sessionStats => _session.state.sessionStats;
  TrainingCelebration? get celebration => _session.state.celebration;
  bool get isSessionFinished => _session.state.sessionStats != null;

  LearningMethod? get currentLearningMethod => _session.state.currentTask?.kind;

  NumberPronunciationState? get numberPronunciationState {
    final task = _session.state.currentTask;
    return task is NumberPronunciationState ? task : null;
  }

  MultipleChoiceState? get multipleChoiceState {
    final task = _session.state.currentTask;
    return task is MultipleChoiceState ? task : null;
  }

  ListeningState? get listeningState {
    final task = _session.state.currentTask;
    return task is ListeningState ? task : null;
  }

  PhrasePronunciationState? get phrasePronunciationState {
    final task = _session.state.currentTask;
    return task is PhrasePronunciationState ? task : null;
  }

  String get displayText => _session.state.currentTask?.displayText ?? '--';
  String? get hintText => numberPronunciationState?.hintText;
  List<String> get expectedTokens =>
      numberPronunciationState?.expectedTokens ?? const <String>[];
  List<bool> get matchedTokens =>
      numberPronunciationState?.matchedTokens ?? const <bool>[];
  String? get lastHeardText => numberPronunciationState?.lastHeardText;
  List<String> get lastHeardTokens =>
      numberPronunciationState?.lastHeardTokens ?? const <String>[];
  List<int> get lastMatchedIndices =>
      numberPronunciationState?.lastMatchedIndices ?? const <int>[];
  String? get previewHeardText => numberPronunciationState?.previewHeardText;
  List<String> get previewHeardTokens =>
      numberPronunciationState?.previewHeardTokens ?? const <String>[];
  List<int> get previewMatchedIndices =>
      numberPronunciationState?.previewMatchedIndices ?? const <int>[];

  bool get isAwaitingRecording =>
      phrasePronunciationState?.flow == PhraseFlow.waiting;
  bool get isRecording =>
      phrasePronunciationState?.flow == PhraseFlow.recording;
  bool get hasRecording => phrasePronunciationState?.hasRecording ?? false;
  bool get isAwaitingPronunciationReview =>
      phrasePronunciationState?.flow == PhraseFlow.reviewing;
  PronunciationAnalysisResult? get pronunciationResult =>
      phrasePronunciationState?.result;

  Stream<List<double>> get soundStream => _session.soundStream;

  Duration get currentCardDuration =>
      _session.state.currentTask?.timer.duration ?? Duration.zero;
  bool get isTimerRunning =>
      _session.state.currentTask?.timer.isRunning ?? false;

  int get totalCards => _session.totalCards;
  int get learnedCount => _session.learnedCount;
  int get remainingCount => _session.remainingCount;
  bool get hasRemainingCards => _session.hasRemainingCards;
  int get dailyGoalCards => _session.dailyGoalCards;
  int get dailyRemainingCards => _session.dailyRemainingCards;
  DateTime? get dailyRecommendedReturn => _session.dailyRecommendedReturn;

  Future<void> initialize() => _session.initialize();
  Future<void> retryInitSpeech() => _session.retryInitSpeech();
  Future<void> startTraining() => _session.startTraining();
  Future<void> stopTraining() => _session.stopTraining();
  Future<void> pauseForOverlay() => _session.pauseForOverlay();
  Future<void> restoreAfterOverlay() => _session.restoreAfterOverlay();
  Future<void> continueSession() => _session.continueSession();
  Future<void> continueAfterCelebration() =>
      _session.continueAfterCelebration();

  Future<void> setPremiumPronunciationEnabled(bool enabled) =>
      _session.setPremiumPronunciationEnabled(enabled);

  Future<void> handleAction(TaskAction action) => _session.handleAction(action);

  Future<void> selectOption(String option) =>
      _session.handleAction(SelectOptionAction(option));

  Future<void> repeatListeningPrompt() =>
      _session.handleAction(const RepeatPromptAction());

  Future<void> startPronunciationRecording() =>
      _session.handleAction(const StartRecordingAction());

  Future<void> stopPronunciationRecording() =>
      _session.handleAction(const StopRecordingAction());

  Future<void> cancelPronunciationRecording() =>
      _session.handleAction(const CancelRecordingAction());

  Future<void> sendPronunciationRecording() =>
      _session.handleAction(const SendRecordingAction());

  Future<void> completePronunciationReview() =>
      _session.handleAction(const CompleteReviewAction());

  Future<void> completeCurrentTaskWithOutcome(TrainingOutcome outcome) =>
      _session.completeCurrentTaskWithOutcome(outcome);

  @override
  void dispose() {
    _disposed = true;
    _session.dispose();
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
