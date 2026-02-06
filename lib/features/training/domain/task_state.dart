import 'pronunciation_models.dart';
import 'time_value.dart';
import 'training_item.dart';
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

  final LearningMethod kind;
  final TrainingItemId taskId;
  final int? numberValue;
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
         kind: LearningMethod.numberPronunciation,
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

final class MultipleChoiceState extends TaskState {
  MultipleChoiceState({
    required super.kind,
    required super.taskId,
    required super.numberValue,
    required super.displayText,
    required super.timer,
    required this.prompt,
    required List<String> options,
  }) : options = List<String>.unmodifiable(options),
       super(affectsProgress: true, usesTimer: true);

  final String prompt;
  final List<String> options;
}

final class ListeningState extends TaskState {
  ListeningState({
    required super.taskId,
    super.numberValue,
    this.timeValue,
    required super.displayText,
    required super.timer,
    required List<String> options,
    required this.isAnswerRevealed,
  }) : options = List<String>.unmodifiable(options),
       super(
         kind: LearningMethod.listening,
         affectsProgress: true,
         usesTimer: true,
       );

  final TimeValue? timeValue;
  final List<String> options;
  final bool isAnswerRevealed;
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
         kind: LearningMethod.phrasePronunciation,
         affectsProgress: false,
         usesTimer: false,
         timer: TimerState.zero,
       );

  final PhraseFlow flow;
  final bool hasRecording;
  final PronunciationAnalysisResult? result;
  final bool isWaveVisible;
}
