import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  TrainingFeedback? get feedback => _session.state.feedback;
  TaskState? get currentTask => _session.state.currentTask;
  TrainingCelebration? get celebration => _session.state.celebration;
  LearningMethod? get currentLearningMethod => _session.state.currentTask?.kind;

  NumberPronunciationState? get numberPronunciationState {
    final task = _session.state.currentTask;
    return task is NumberPronunciationState ? task : null;
  }

  PhrasePronunciationState? get phrasePronunciationState {
    final task = _session.state.currentTask;
    return task is PhrasePronunciationState ? task : null;
  }

  bool get hasRecording => phrasePronunciationState?.hasRecording ?? false;

  Stream<List<double>> get soundStream => _session.soundStream;

  int get dailyGoalCards => _session.dailyGoalCards;
  int get sessionCardsCompleted => _session.sessionCardsCompleted;
  int get sessionTargetCards => _session.sessionTargetCards;

  Future<void> initialize() => _session.initialize();
  Future<void> retryInitSpeech() => _session.retryInitSpeech();
  Future<void> startTraining() => _session.startTraining();
  Future<void> stopTraining() => _session.stopTraining();
  Future<void> continueSession() => _session.continueSession();
  Future<void> continueAfterCelebration() =>
      _session.continueAfterCelebration();
  Future<void> pauseTaskTimer() => _session.pauseTaskTimer();
  Future<void> resumeTaskTimer() => _session.resumeTaskTimer();

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

  Future<void> completeCurrentTaskWithOutcome(
    TrainingOutcome outcome, {
    bool simulatedUserInteraction = false,
  }) => _session.completeCurrentTaskWithOutcome(
    outcome,
    simulatedUserInteraction: simulatedUserInteraction,
  );

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
