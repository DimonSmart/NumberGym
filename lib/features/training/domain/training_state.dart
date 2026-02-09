import 'task_state.dart';
import 'training_outcome.dart';

class TrainingFeedback {
  final TrainingOutcome outcome;
  final String text;

  const TrainingFeedback({required this.outcome, required this.text});
}

class SessionStats {
  final int cardsCompleted;
  final Duration duration;
  final int sessionsCompletedToday;
  final int cardsCompletedToday;
  final Duration durationToday;

  const SessionStats({
    required this.cardsCompleted,
    required this.duration,
    required this.sessionsCompletedToday,
    required this.cardsCompletedToday,
    required this.durationToday,
  });
}

class TrainingCelebration {
  const TrainingCelebration({required this.eventId, required this.counter});

  final int eventId;
  final int counter;
}

class TrainingState {
  final bool speechReady;
  final String? errorMessage;
  final TrainingFeedback? feedback;
  final TaskState? currentTask;
  final SessionStats? sessionStats;
  final TrainingCelebration? celebration;

  const TrainingState({
    required this.speechReady,
    required this.errorMessage,
    required this.feedback,
    required this.currentTask,
    this.sessionStats,
    this.celebration,
  });

  factory TrainingState.initial() {
    return const TrainingState(
      speechReady: false,
      errorMessage: null,
      feedback: null,
      currentTask: null,
      sessionStats: null,
      celebration: null,
    );
  }
}
