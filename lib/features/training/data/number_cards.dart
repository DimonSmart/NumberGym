import '../domain/learning_language.dart';
import '../domain/tasks/number_pronunciation_task.dart';
import '../domain/training_item.dart';
import '../languages/language_pack.dart';
import '../languages/registry.dart';
import 'time_cards.dart';

List<TrainingItemId> buildAllCardIds() {
  return [
    ...buildNumberCardIds(),
    ...buildTimeCardIds(),
  ];
}

List<TrainingItemId> buildNumberCardIds() {
  final ids = <TrainingItemId>[];
  for (var i = 0; i <= 9; i++) {
    ids.add(
      TrainingItemId(
        type: TrainingItemType.digits,
        number: i,
      ),
    );
  }
  for (var i = 10; i <= 99; i++) {
    ids.add(
      TrainingItemId(
        type: TrainingItemType.base,
        number: i,
      ),
    );
  }
  for (var i = 100; i <= 900; i += 100) {
    ids.add(
      TrainingItemId(
        type: TrainingItemType.hundreds,
        number: i,
      ),
    );
  }
  for (var i = 1000; i <= 9000; i += 1000) {
    ids.add(
      TrainingItemId(
        type: TrainingItemType.thousands,
        number: i,
      ),
    );
  }
  return ids;
}

List<NumberPronunciationTask> buildNumberCards({
  required LearningLanguage language,
  NumberWordsConverter? toWords,
}) {
  final ids = buildNumberCardIds();
  final converter = toWords ?? LanguageRegistry.of(language).numberWordsConverter;
  return ids.map((id) {
    final value = id.number!;
    final prompt = value.toString();
    return NumberPronunciationTask(
      id: id,
      numberValue: value,
      prompt: prompt,
      language: language,
      answers: <String>[
        converter(value),
        prompt,
      ],
    );
  }).toList();
}
