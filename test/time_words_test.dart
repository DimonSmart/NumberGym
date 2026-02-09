import 'package:flutter_test/flutter_test.dart';

import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/time_value.dart';
import 'package:number_gym/features/training/languages/registry.dart';

void main() {
  test('23:45 uses midnight wording in every language', () {
    const quarterToMidnight = TimeValue(hour: 23, minute: 45);
    const midnight = TimeValue(hour: 0, minute: 0);

    for (final language in LearningLanguage.values) {
      final converter = LanguageRegistry.of(language).timeWordsConverter;
      final midnightWords = converter(midnight);
      final quarterToMidnightWords = converter(quarterToMidnight);

      expect(
        quarterToMidnightWords.contains(midnightWords),
        isTrue,
        reason:
            '$language should mention midnight for 23:45, got "$quarterToMidnightWords" (midnight: "$midnightWords")',
      );
    }
  });

  test('Spanish 23:45 is medianoche menos cuarto', () {
    final converter = LanguageRegistry.of(
      LearningLanguage.spanish,
    ).timeWordsConverter;

    expect(
      converter(const TimeValue(hour: 23, minute: 45)),
      'medianoche menos cuarto',
    );
  });
}
