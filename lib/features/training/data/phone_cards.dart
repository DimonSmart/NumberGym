import 'dart:math';

import '../domain/learning_language.dart';
import '../domain/tasks/phone_pronunciation_task.dart';
import '../domain/training_item.dart';
import '../languages/registry.dart';

const int _phoneCardsPerFormat = 16;
const int _countryCode = 34;

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
    cards.add(
      buildPhoneCardForLocalNumber(
        id: id,
        localNumber: localNumber,
        language: language,
        includePrefix: localNumber.isEven,
      ),
    );
  }
  return cards;
}

PhonePronunciationTask buildRandomPhoneCard({
  required TrainingItemId id,
  required LearningLanguage language,
  required Random random,
  String Function(int)? toWords,
}) {
  final localNumber = buildRandomPhoneLocalNumber(id.type, random);
  return buildPhoneCardForLocalNumber(
    id: id,
    localNumber: localNumber,
    language: language,
    includePrefix: random.nextBool(),
    toWords: toWords,
  );
}

PhonePronunciationTask buildPhoneCardForLocalNumber({
  required TrainingItemId id,
  required int localNumber,
  required LearningLanguage language,
  required bool includePrefix,
  String Function(int)? toWords,
}) {
  final groupedLocal = _groupNumber(localNumber, id.type);
  final prompt = includePrefix ? '+$_countryCode $groupedLocal' : groupedLocal;
  final compact = groupedLocal.replaceAll(' ', '');
  final spokenPrompt = _spokenPrompt(
    groupedLocal: groupedLocal,
    language: language,
    includePrefix: includePrefix,
    toWords: toWords,
  );

  final answers = <String>[];
  void addAnswer(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    final exists = answers.any(
      (answer) => answer.toLowerCase() == normalized.toLowerCase(),
    );
    if (!exists) {
      answers.add(normalized);
    }
  }

  addAnswer(prompt);
  addAnswer(spokenPrompt);
  addAnswer(groupedLocal);
  addAnswer(compact);
  if (includePrefix) {
    addAnswer('+$_countryCode$compact');
    addAnswer('$_countryCode$compact');
  }

  return PhonePronunciationTask(
    id: id,
    numberValue: localNumber,
    prompt: prompt,
    language: language,
    answers: answers,
  );
}

int _uniqueLocalNumber(TrainingItemType type, Random random, Set<int> seen) {
  while (true) {
    final number = buildRandomPhoneLocalNumber(type, random);
    if (seen.add(number)) {
      return number;
    }
  }
}

int buildRandomPhoneLocalNumber(TrainingItemType type, Random random) {
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

String _spokenPrompt({
  required String groupedLocal,
  required LearningLanguage language,
  required bool includePrefix,
  String Function(int)? toWords,
}) {
  final converter =
      toWords ?? LanguageRegistry.of(language).numberWordsConverter;
  final localWords = _groupedDigitsToWords(groupedLocal, converter);
  if (!includePrefix) {
    return localWords;
  }
  final prefixWords = converter(_countryCode);
  return '${_plusWord(language)} $prefixWords $localWords';
}

String _groupedDigitsToWords(
  String groupedDigits,
  String Function(int) converter,
) {
  final words = <String>[];
  for (final group in groupedDigits.split(_whitespaceRegex)) {
    if (group.isEmpty) {
      continue;
    }
    words.add(_groupToWords(group, converter));
  }
  return words.join(' ').trim();
}

String _groupToWords(String group, String Function(int) converter) {
  if (group.length > 1 && group.startsWith('0')) {
    return _digitsToWords(group, converter);
  }
  final value = int.tryParse(group);
  if (value == null) {
    return _digitsToWords(group, converter);
  }
  return converter(value);
}

String _digitsToWords(String digits, String Function(int) converter) {
  final words = <String>[];
  for (final rune in digits.runes) {
    final char = String.fromCharCode(rune);
    final value = int.tryParse(char);
    if (value == null) {
      continue;
    }
    words.add(converter(value));
  }
  return words.join(' ').trim();
}

String _plusWord(LearningLanguage language) {
  final pack = LanguageRegistry.of(language);
  for (final entry in pack.operatorWords.entries) {
    if (entry.value == 'PLUS') {
      return entry.key;
    }
  }
  return 'plus';
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

final _whitespaceRegex = RegExp(r'\s+');
