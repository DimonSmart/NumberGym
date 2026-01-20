import '../domain/learning_language.dart';

class NumberCard {
  final int id;
  final String prompt;
  final Map<LearningLanguage, List<String>> answersByLanguage;

  const NumberCard({
    required this.id,
    required this.prompt,
    required this.answersByLanguage,
  });

  List<String> answersFor(LearningLanguage language) {
    return answersByLanguage[language] ?? const <String>[];
  }
}
