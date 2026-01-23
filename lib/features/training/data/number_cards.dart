import '../domain/learning_language.dart';
import '../domain/tasks/number_pronunciation_task.dart';
import 'number_words.dart';

List<int> buildNumberCardIds() {
  final ids = <int>[];
  // 0 - 100
  for (var i = 0; i <= 100; i++) {
    ids.add(i);
  }
  // 200 - 900
  for (var i = 200; i < 1000; i += 100) {
    ids.add(i);
  }
  // Powers of 10
  ids.add(1000);
  ids.add(10000);
  ids.add(100000);
  ids.add(1000000);
  return ids;
}

List<NumberPronunciationTask> buildNumberCards({
  required LearningLanguage language,
  NumberWordsConverter? toWords,
}) {
  final ids = buildNumberCardIds();
  final converter = toWords ?? numberWordsFor(language);
  return ids.map((id) {
    final prompt = id.toString();
    return NumberPronunciationTask(
      id: id,
      prompt: prompt,
      language: language,
      answers: <String>[
        converter(id),
        prompt,
      ],
    );
  }).toList();
}
