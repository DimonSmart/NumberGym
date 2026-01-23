import 'task_state.dart';

enum TrainerStatus { idle, running, waitingRecording, paused, finished }

enum TrainingFeedbackType { correct, wrong, timeout, skipped }

class TrainingFeedback {
  final TrainingFeedbackType type;
  final String text;

  const TrainingFeedback({
    required this.type,
    required this.text,
  });
}

class TrainingState {
  final TrainerStatus status;
  final bool speechReady;
  final String? errorMessage;
  final TrainingFeedback? feedback;
  final TaskState? currentTask;

  const TrainingState({
    required this.status,
    required this.speechReady,
    required this.errorMessage,
    required this.feedback,
    required this.currentTask,
  });

  factory TrainingState.initial() {
    return const TrainingState(
      status: TrainerStatus.idle,
      speechReady: false,
      errorMessage: null,
      feedback: null,
      currentTask: null,
    );
  }
}
