import 'task_state.dart';
import 'training_outcome.dart';

class TrainingFeedback {
  final TrainingOutcome outcome;
  final String text;

  const TrainingFeedback({
    required this.outcome,
    required this.text,
  });
}

class TrainingState {
  final bool speechReady;
  final String? errorMessage;
  final TrainingFeedback? feedback;
  final TaskState? currentTask;

  const TrainingState({
    required this.speechReady,
    required this.errorMessage,
    required this.feedback,
    required this.currentTask,
  });

  factory TrainingState.initial() {
    return const TrainingState(
      speechReady: false,
      errorMessage: null,
      feedback: null,
      currentTask: null,
    );
  }
}
