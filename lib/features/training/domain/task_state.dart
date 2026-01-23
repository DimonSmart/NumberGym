import 'pronunciation_models.dart';
import 'training_task.dart';

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
    required this.kind,
    required this.taskId,
    required this.numberValue,
    required this.displayText,
    required this.affectsProgress,
    required this.usesTimer,
    required this.timer,
  });

  final TrainingTaskKind kind;
  final int taskId;
  final int numberValue;
  final String displayText;
  final bool affectsProgress;
  final bool usesTimer;
  final TimerState timer;
}

final class NumberPronunciationState extends TaskState {
  NumberPronunciationState({
    required super.taskId,
    required super.numberValue,
    required super.displayText,
    required super.timer,
    required this.expectedTokens,
    required this.matchedTokens,
    required this.hintText,
    required this.isListening,
    required this.speechReady,
  }) : super(
          kind: TrainingTaskKind.numberPronunciation,
          affectsProgress: true,
          usesTimer: true,
        );

  final List<String> expectedTokens;
  final List<bool> matchedTokens;
  final String? hintText;
  final bool isListening;
  final bool speechReady;
}

final class MultipleChoiceState extends TaskState {
  MultipleChoiceState({
    required super.kind,
    required super.taskId,
    required super.numberValue,
    required super.displayText,
    required super.timer,
    required this.prompt,
    required List<String> options,
  })  : options = List<String>.unmodifiable(options),
        super(
          affectsProgress: true,
          usesTimer: true,
        );

  final String prompt;
  final List<String> options;
}

enum PhraseFlow { waiting, recording, recorded, sending, reviewing }

final class PhrasePronunciationState extends TaskState {
  PhrasePronunciationState({
    required super.taskId,
    required super.numberValue,
    required super.displayText,
    required this.flow,
    required this.hasRecording,
    required this.result,
    required this.isWaveVisible,
  }) : super(
          kind: TrainingTaskKind.phrasePronunciation,
          affectsProgress: false,
          usesTimer: false,
          timer: TimerState.zero,
        );

  final PhraseFlow flow;
  final bool hasRecording;
  final PronunciationAnalysisResult? result;
  final bool isWaveVisible;
}
