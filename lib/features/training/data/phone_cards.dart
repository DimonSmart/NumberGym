import 'dart:math';

import '../domain/learning_language.dart';
import '../domain/tasks/phone_pronunciation_task.dart';
import '../domain/training_item.dart';

const int _phoneCardsPerFormat = 16;

List<TrainingItemId> buildPhoneCardIds() {
  final ids = <TrainingItemId>[];
  final seen = <int>{};
  final rng = Random(34034);
  for (var i = 0; i < _phoneCardsPerFormat; i += 1) {
    ids.add(
      TrainingItemId(
        type: TrainingItemType.phone33x3,
        number: _uniqueLocalNumber(TrainingItemType.phone33x3, rng, seen),
      ),
    );
    ids.add(
      TrainingItemId(
        type: TrainingItemType.phone3222,
        number: _uniqueLocalNumber(TrainingItemType.phone3222, rng, seen),
      ),
    );
    ids.add(
      TrainingItemId(
        type: TrainingItemType.phone2322,
        number: _uniqueLocalNumber(TrainingItemType.phone2322, rng, seen),
      ),
    );
  }
  return ids;
}

List<PhonePronunciationTask> buildPhoneCards({
  required LearningLanguage language,
}) {
  final cards = <PhonePronunciationTask>[];
  for (final id in buildPhoneCardIds()) {
    final localNumber = id.number!;
    final includePrefix = localNumber.isEven;
    final groupedLocal = _groupNumber(localNumber, id.type);
    final prompt = includePrefix ? '+34 $groupedLocal' : groupedLocal;
    final compact = groupedLocal.replaceAll(' ', '');
    final answers = <String>{
      prompt,
      groupedLocal,
      compact,
      if (includePrefix) '+34$compact',
      if (includePrefix) '34$compact',
    }.toList();
    cards.add(
      PhonePronunciationTask(
        id: id,
        numberValue: localNumber,
        prompt: prompt,
        language: language,
        answers: answers,
      ),
    );
  }
  return cards;
}

int _uniqueLocalNumber(TrainingItemType type, Random random, Set<int> seen) {
  while (true) {
    final number = _buildLocalNumber(type, random);
    if (seen.add(number)) {
      return number;
    }
  }
}

int _buildLocalNumber(TrainingItemType type, Random random) {
  final firstDigits = switch (type) {
    TrainingItemType.phone33x3 ||
    TrainingItemType.phone3222 => random.nextBool() ? 6 : 7,
    TrainingItemType.phone2322 => random.nextBool() ? 8 : 9,
    _ => 6,
  };
  var number = firstDigits;
  for (var i = 0; i < 8; i += 1) {
    number = number * 10 + random.nextInt(10);
  }
  return number;
}

String _groupNumber(int localNumber, TrainingItemType type) {
  final digits = localNumber.toString().padLeft(9, '0');
  final pattern = switch (type) {
    TrainingItemType.phone33x3 => const <int>[3, 3, 3],
    TrainingItemType.phone3222 => const <int>[3, 2, 2, 2],
    TrainingItemType.phone2322 => const <int>[2, 3, 2, 2],
    _ => const <int>[3, 3, 3],
  };
  final groups = <String>[];
  var cursor = 0;
  for (final size in pattern) {
    groups.add(digits.substring(cursor, cursor + size));
    cursor += size;
  }
  return groups.join(' ');
}
