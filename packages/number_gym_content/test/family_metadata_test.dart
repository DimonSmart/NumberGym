import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym_content/number_gym_content.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  final module = NumberGymModule();

  group('phone family labels', () {
    final phoneIds = {'phone33x3', 'phone3222', 'phone2322'};
    final families = module
        .buildFamilies(LearningLanguage.spanish)
        .where((f) => phoneIds.contains(f.id))
        .toList();

    test('label and shortLabel for each phone format', () {
      final byId = {for (final f in families) f.id: f};

      expect(byId['phone33x3']!.label, 'Phone numbers (3-3-3)');
      expect(byId['phone33x3']!.shortLabel, 'Phone 3-3-3');

      expect(byId['phone3222']!.label, 'Phone numbers (3-2-2-2)');
      expect(byId['phone3222']!.shortLabel, 'Phone 3-2-2-2');

      expect(byId['phone2322']!.label, 'Phone numbers (2-3-2-2)');
      expect(byId['phone2322']!.shortLabel, 'Phone 2-3-2-2');
    });
  });

  group('celebrationText format', () {
    const language = LearningLanguage.spanish;

    test('number card celebrationText is "displayText -> spoken"', () {
      final card = module
          .buildCards(language)
          .firstWhere((c) => c.id.familyId == 'digits' && c.id.variantId == '7');

      expect(card.celebrationText, contains(' -> '));
      final parts = card.celebrationText.split(' -> ');
      expect(parts.length, 2);
      expect(parts[0], card.displayText);
      expect(parts[1].trim(), isNotEmpty);
    });

    test('time card celebrationText is "displayText -> spoken"', () {
      final card = module
          .buildCards(language)
          .firstWhere((c) => c.id.familyId == 'timeExact');

      expect(card.celebrationText, contains(' -> '));
      final parts = card.celebrationText.split(' -> ');
      expect(parts.length, 2);
      expect(parts[0], card.displayText);
      expect(parts[1].trim(), isNotEmpty);
    });

    test('phone card celebrationText is "prompt -> spokenPrompt"', () {
      final phoneCard = module
          .buildCards(language)
          .firstWhere(
            (c) => c.id.familyId == 'phone33x3' && c.dynamicResolver != null,
          )
          .resolveDynamic();

      expect(phoneCard.celebrationText, contains(' -> '));
      final parts = phoneCard.celebrationText.split(' -> ');
      expect(parts.length, 2);
      expect(parts[0], phoneCard.promptText);
      expect(parts[1].trim(), isNotEmpty);
    });
  });
}
