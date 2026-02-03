import 'dart:math';

import '../domain/learning_language.dart';
import '../domain/time_value.dart';
import '../domain/training_item.dart';
import '../domain/tasks/time_pronunciation_task.dart';

List<TrainingItemId> buildTimeCardIds() {
  final ids = <TrainingItemId>[];
  for (var hour = 0; hour < 24; hour += 1) {
    ids.add(
      TrainingItemId(
        type: TrainingItemType.timeExact,
        time: TimeValue(hour: hour, minute: 0),
      ),
    );
    ids.add(
      TrainingItemId(
        type: TrainingItemType.timeHalf,
        time: TimeValue(hour: hour, minute: 30),
      ),
    );
    ids.add(
      TrainingItemId(
        type: TrainingItemType.timeQuarter,
        time: TimeValue(hour: hour, minute: 15),
      ),
    );
    ids.add(
      TrainingItemId(
        type: TrainingItemType.timeQuarter,
        time: TimeValue(hour: hour, minute: 45),
      ),
    );
  }
  ids.add(
    const TrainingItemId(
      type: TrainingItemType.timeRandom,
      time: null,
    ),
  );
  return ids;
}

List<TimePronunciationTask> buildTimeCards({
  required LearningLanguage language,
  String Function(TimeValue time)? toWords,
  Random? random,
}) {
  final ids = buildTimeCardIds();
  final rng = random ?? Random();
  return ids.map((id) {
    final value = id.time ?? _randomTime(rng);
    final numeric = value.displayText;
    final words = toWords?.call(value) ?? numeric;
    final prompt =
        id.type == TrainingItemType.timeExact ? numeric : words;
    final answers = <String>[];
    void addAnswer(String text) {
      if (text.trim().isEmpty) return;
      if (answers.any((answer) => answer.toLowerCase() == text.toLowerCase())) {
        return;
      }
      answers.add(text);
    }

    addAnswer(prompt);
    addAnswer(words);
    addAnswer(numeric);
    return TimePronunciationTask(
      id: id,
      timeValue: value,
      prompt: prompt,
      language: language,
      answers: answers,
    );
  }).toList();
}

TimeValue _randomTime(Random random) {
  return TimeValue(
    hour: random.nextInt(24),
    minute: random.nextInt(60),
  );
}
