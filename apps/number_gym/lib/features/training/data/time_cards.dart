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
    return TimePronunciationTask.forTime(
      id: id,
      timeValue: value,
      language: language,
      toWords: toWords,
    );
  }).toList();
}

TimeValue _randomTime(Random random) {
  return TimeValue(
    hour: random.nextInt(24),
    minute: random.nextInt(60),
  );
}
