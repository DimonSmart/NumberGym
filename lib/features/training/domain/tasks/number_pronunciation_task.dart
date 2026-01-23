import '../learning_language.dart';
import '../training_task.dart';

class NumberPronunciationTask extends NumberTrainingTask {
  final String prompt;
  final LearningLanguage language;
  final List<String> answers;

  const NumberPronunciationTask({
    required super.id,
    required this.prompt,
    required this.language,
    required this.answers,
  }) : super(
          numberValue: id,
          kind: TrainingTaskKind.numberPronunciation,
        );

  @override
  String get displayText => prompt;
}
