import '../learning_language.dart';
import '../training_task.dart';

class NumberPronunciationTask extends NumberTrainingTask
    implements PronunciationTaskData {
  final String prompt;
  final LearningLanguage language;
  final List<String> answers;

  NumberPronunciationTask({
    required super.id,
    required super.numberValue,
    required this.prompt,
    required this.language,
    required this.answers,
  })  : assert(id.number == numberValue),
        super(
          kind: TrainingTaskKind.numberPronunciation,
        );

  @override
  String get displayText => prompt;
}
