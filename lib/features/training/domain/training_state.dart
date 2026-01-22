import '../data/number_card.dart';

enum TrainerStatus { idle, running, paused, finished }

enum TrainingFeedbackType { correct, wrong, timeout }

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
  final SpeakNumberTask? currentCard;
  final String? hintText;
  final List<String> expectedTokens;
  final List<bool> matchedTokens;
  final Duration cardDuration;
  final bool isTimerRunning;

  const TrainingState({
    required this.status,
    required this.speechReady,
    required this.errorMessage,
    required this.feedback,
    required this.currentCard,
    required this.hintText,
    required this.expectedTokens,
    required this.matchedTokens,
    required this.cardDuration,
    required this.isTimerRunning,
  });

  factory TrainingState.initial() {
    return const TrainingState(
      status: TrainerStatus.idle,
      speechReady: false,
      errorMessage: null,
      feedback: null,
      currentCard: null,
      hintText: null,
      expectedTokens: <String>[],
      matchedTokens: <bool>[],
      cardDuration: Duration.zero,
      isTimerRunning: false,
    );
  }
}
