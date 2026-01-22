import '../domain/learning_language.dart';
import '../domain/training_task.dart';

class SpeakNumberTask extends TrainingTask {
  final String prompt;
  final Map<LearningLanguage, List<String>> answersByLanguage;

  const SpeakNumberTask({
    required super.id,
    required this.prompt,
    required this.answersByLanguage,
  });

  List<String> answersFor(LearningLanguage language) {
    return answersByLanguage[language] ?? const <String>[];
  }
}
