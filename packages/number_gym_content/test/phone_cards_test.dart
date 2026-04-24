import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym_content/number_gym_content.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  final phoneIds = const {'phone33x3', 'phone3222', 'phone2322'};

  group('phone families', () {
    final module = NumberGymModule();
    final families = module
        .buildFamilies(LearningLanguage.spanish)
        .where((f) => phoneIds.contains(f.id))
        .toList();

    test('all three phone formats are present', () {
      expect(families.map((f) => f.id).toSet(), equals(phoneIds));
    });

    test('phone families support only speak mode', () {
      for (final family in families) {
        expect(family.supportedModes, equals(const [ExerciseMode.speak]));
      }
    });

    test('phone families have 0.8 mastery accuracy', () {
      for (final family in families) {
        expect(family.masteryAccuracy, 0.8);
      }
    });
  });

  group('phone cards', () {
    final module = NumberGymModule();
    final cards = module
        .buildCards(LearningLanguage.spanish)
        .where((card) => phoneIds.contains(card.id.familyId))
        .toList();

    test('both +34 prefix and non-prefix variants exist', () {
      var hasPrefix = false;
      var withoutPrefix = false;
      for (final card in cards) {
        if (card.displayText.startsWith('+34 ')) {
          hasPrefix = true;
        } else {
          withoutPrefix = true;
        }
      }
      expect(hasPrefix, isTrue);
      expect(withoutPrefix, isTrue);
    });

    test('display text has 9 or 11 digit count', () {
      for (final card in cards) {
        final digits = card.displayText.replaceAll(RegExp(r'\D'), '');
        expect(
          digits.length == 9 || digits.length == 11,
          isTrue,
          reason: 'card ${card.displayText} has ${digits.length} digits',
        );
      }
    });

    test('spoken hint contains word characters, not just digits', () {
      for (final card in cards) {
        final promptLower = card.promptText.trim().toLowerCase();
        final hint = card.acceptedAnswers.firstWhere(
          (a) => a.trim().toLowerCase() != promptLower,
        );
        expect(
          RegExp(r'^[+\d\s]+$').hasMatch(hint),
          isFalse,
          reason: 'hint for ${card.displayText} should contain words',
        );
      }
    });

    test('spoken hint uses grouped chunk separators', () {
      for (final card in cards) {
        final promptLower = card.promptText.trim().toLowerCase();
        final hint = card.acceptedAnswers.firstWhere(
          (a) => a.trim().toLowerCase() != promptLower,
        );
        expect(
          hint.contains(' • '),
          isTrue,
          reason: 'hint for ${card.displayText} should use grouped chunks',
        );
      }
    });

    test('dynamic resolution changes phone prompt between consecutive calls', () {
      final module = NumberGymModule(random: Random(42));
      final card = module
          .buildCards(LearningLanguage.spanish)
          .where(
            (c) => phoneIds.contains(c.id.familyId) && c.dynamicResolver != null,
          )
          .first;

      final prompts = <String>{};
      for (var i = 0; i < 20; i++) {
        prompts.add(card.dynamicResolver!().promptText);
      }

      expect(prompts.length, greaterThan(1));
    });
  });
}
