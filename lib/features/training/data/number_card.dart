import '../domain/learning_language.dart';
import '../domain/training_task.dart';

class NumberPronunciationTask extends NumberTrainingTask {
  final String prompt;
  final Map<LearningLanguage, List<String>> answersByLanguage;

  const NumberPronunciationTask({
    required super.id,
    required this.prompt,
    required this.answersByLanguage,
  }) : super(
          numberValue: id,
          kind: TrainingTaskKind.numberPronunciation,
        );

  @override
  String get displayText => prompt;

  List<String> answersFor(LearningLanguage language) {
    return answersByLanguage[language] ?? const <String>[];
  }
}
