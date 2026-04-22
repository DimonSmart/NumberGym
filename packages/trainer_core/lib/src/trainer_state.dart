import 'exercise_models.dart';
import 'training/domain/pronunciation_models.dart';

enum TrainingOutcome { correct, wrong, timeout, skipped }

class TrainingFeedback {
  const TrainingFeedback({required this.outcome});

  final TrainingOutcome outcome;
}

class SessionStats {
  const SessionStats({
    required this.cardsCompleted,
    required this.duration,
    required this.sessionsCompletedToday,
    required this.cardsCompletedToday,
    required this.durationToday,
  });

  final int cardsCompleted;
  final Duration duration;
  final int sessionsCompletedToday;
  final int cardsCompletedToday;
  final Duration durationToday;
}

class TrainingCelebration {
  const TrainingCelebration({
    required this.eventId,
    required this.counter,
    required this.masteredText,
    required this.modeLabel,
    required this.categoryLabel,
  });

  final int eventId;
  final int counter;
  final String masteredText;
  final String modeLabel;
  final String categoryLabel;
}

class TimerState {
  const TimerState({
    required this.isRunning,
    required this.duration,
    required this.remaining,
  });

  final bool isRunning;
  final Duration duration;
  final Duration remaining;

  static const zero = TimerState(
    isRunning: false,
    duration: Duration.zero,
    remaining: Duration.zero,
  );
}

sealed class TaskState {
  const TaskState({
    required this.mode,
    required this.exerciseId,
    required this.family,
    required this.displayText,
    required this.promptText,
    required this.acceptedAnswers,
    required this.celebrationText,
    required this.affectsProgress,
    required this.usesTimer,
    required this.timer,
  });

  final ExerciseMode mode;
  final ExerciseId exerciseId;
  final ExerciseFamily family;
  final String displayText;
  final String promptText;
  final List<String> acceptedAnswers;
  final String celebrationText;
  final bool affectsProgress;
  final bool usesTimer;
  final TimerState timer;
}

final class SpeakState extends TaskState {
  SpeakState({
    required super.exerciseId,
    required super.family,
    required super.displayText,
    required super.promptText,
    required super.acceptedAnswers,
    required super.celebrationText,
    required super.timer,
    required List<String> expectedTokens,
    required List<bool> matchedTokens,
    required this.lastHeardText,
    required List<String> lastHeardTokens,
    required List<int> lastMatchedIndices,
    required this.previewHeardText,
    required List<String> previewHeardTokens,
    required List<int> previewMatchedIndices,
    required this.hintText,
    required this.isListening,
    required this.speechReady,
  }) : expectedTokens = List<String>.unmodifiable(expectedTokens),
       matchedTokens = List<bool>.unmodifiable(matchedTokens),
       lastHeardTokens = List<String>.unmodifiable(lastHeardTokens),
       lastMatchedIndices = List<int>.unmodifiable(lastMatchedIndices),
       previewHeardTokens = List<String>.unmodifiable(previewHeardTokens),
       previewMatchedIndices = List<int>.unmodifiable(previewMatchedIndices),
       super(
         mode: ExerciseMode.speak,
         affectsProgress: true,
         usesTimer: true,
       );

  final List<String> expectedTokens;
  final List<bool> matchedTokens;
  final String? lastHeardText;
  final List<String> lastHeardTokens;
  final List<int> lastMatchedIndices;
  final String? previewHeardText;
  final List<String> previewHeardTokens;
  final List<int> previewMatchedIndices;
  final String? hintText;
  final bool isListening;
  final bool speechReady;
}

final class ChoiceState extends TaskState {
  ChoiceState({
    required super.mode,
    required super.exerciseId,
    required super.family,
    required super.displayText,
    required super.promptText,
    required super.acceptedAnswers,
    required super.celebrationText,
    required super.timer,
    required List<String> options,
  }) : options = List<String>.unmodifiable(options),
       super(affectsProgress: true, usesTimer: true);

  final List<String> options;
}

final class ListenAndChooseState extends TaskState {
  ListenAndChooseState({
    required super.exerciseId,
    required super.family,
    required super.displayText,
    required super.promptText,
    required super.acceptedAnswers,
    required super.celebrationText,
    required super.timer,
    required List<String> options,
    required this.correctAnswer,
    required this.isAnswerRevealed,
    required this.isPromptPlaying,
  }) : options = List<String>.unmodifiable(options),
       super(
         mode: ExerciseMode.listenAndChoose,
         affectsProgress: true,
         usesTimer: true,
       );

  final List<String> options;
  final String correctAnswer;
  final bool isAnswerRevealed;
  final bool isPromptPlaying;
}

enum ReviewFlow { waiting, recording, recorded, sending, reviewing }

final class ReviewPronunciationState extends TaskState {
  ReviewPronunciationState({
    required super.exerciseId,
    required super.family,
    required super.displayText,
    required super.promptText,
    required super.acceptedAnswers,
    required super.celebrationText,
    required this.flow,
    required this.hasRecording,
    required this.result,
    required this.isWaveVisible,
  }) : super(
         mode: ExerciseMode.reviewPronunciation,
         affectsProgress: false,
         usesTimer: false,
         timer: TimerState.zero,
       );

  final ReviewFlow flow;
  final bool hasRecording;
  final PronunciationAnalysisResult? result;
  final bool isWaveVisible;
}

class TrainingState {
  const TrainingState({
    required this.errorMessage,
    required this.feedback,
    required this.currentTask,
    this.sessionStats,
    this.celebration,
  });

  final String? errorMessage;
  final TrainingFeedback? feedback;
  final TaskState? currentTask;
  final SessionStats? sessionStats;
  final TrainingCelebration? celebration;

  factory TrainingState.initial() {
    return const TrainingState(
      errorMessage: null,
      feedback: null,
      currentTask: null,
      sessionStats: null,
      celebration: null,
    );
  }
}
