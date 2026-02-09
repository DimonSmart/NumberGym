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
  const TrainingCelebration({
    required this.eventId,
    required this.counter,
    required this.masteredText,
    required this.learningMethodLabel,
    required this.categoryLabel,
    required this.sessionCardsCompleted,
    required this.sessionTargetCards,
    required this.cardsLearnedTotal,
    required this.cardsRemainingTotal,
    required this.cardsCompletedToday,
    required this.cardsTargetToday,
  });

  final int eventId;
  final int counter;
  final String masteredText;
  final String learningMethodLabel;
  final String categoryLabel;
  final int sessionCardsCompleted;
  final int sessionTargetCards;
  final int cardsLearnedTotal;
  final int cardsRemainingTotal;
  final int cardsCompletedToday;
  final int cardsTargetToday;
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
