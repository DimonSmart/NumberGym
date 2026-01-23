import '../data/number_card.dart';
import 'pronunciation_models.dart';
import 'training_task.dart';

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
  final TrainingTask? currentTask;
  final NumberPronunciationTask? currentCard;
  final String displayText;
  final String? hintText;
  final List<String> expectedTokens;
  final List<bool> matchedTokens;
  final Duration cardDuration;
  final bool isTimerRunning;
  final bool isAwaitingRecording;
  final bool isRecording;
  final bool hasRecording;
  final bool isAwaitingPronunciationReview;
  final PronunciationAnalysisResult? pronunciationResult;

  const TrainingState({
    required this.status,
    required this.speechReady,
    required this.errorMessage,
    required this.feedback,
    required this.currentTask,
    required this.currentCard,
    required this.displayText,
    required this.hintText,
    required this.expectedTokens,
    required this.matchedTokens,
    required this.cardDuration,
    required this.isTimerRunning,
    required this.isAwaitingRecording,
    required this.isRecording,
    required this.hasRecording,
    required this.isAwaitingPronunciationReview,
    required this.pronunciationResult,
  });

  factory TrainingState.initial() {
    return const TrainingState(
      status: TrainerStatus.idle,
      speechReady: false,
      errorMessage: null,
      feedback: null,
      currentTask: null,
      currentCard: null,
      displayText: '--',
      hintText: null,
      expectedTokens: <String>[],
      matchedTokens: <bool>[],
      cardDuration: Duration.zero,
      isTimerRunning: false,
      isAwaitingRecording: false,
      isRecording: false,
      hasRecording: false,
      isAwaitingPronunciationReview: false,
      pronunciationResult: null,
    );
  }
}
