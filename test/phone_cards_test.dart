import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/phone_cards.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_params.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';

void main() {
  test('builds phone cards with supported formats and optional +34 prefix', () {
    final cards = buildPhoneCards(language: LearningLanguage.spanish);

    expect(cards, isNotEmpty);
    final supportedTypes = {
      TrainingItemType.phone33x3,
      TrainingItemType.phone3222,
      TrainingItemType.phone2322,
    };

    var hasPrefix = false;
    var withoutPrefix = false;

    for (final card in cards) {
      expect(supportedTypes.contains(card.id.type), isTrue);
      final digits = card.displayText.replaceAll(RegExp(r'\D'), '');
      expect(digits.length == 9 || digits.length == 11, isTrue);
      if (card.displayText.startsWith('+34 ')) {
        hasPrefix = true;
      } else {
        withoutPrefix = true;
      }
    }

    expect(hasPrefix, isTrue);
    expect(withoutPrefix, isTrue);
  });

  test('phone card types are available only in pronunciation mode', () {
    const phoneTypes = {
      TrainingItemType.phone33x3,
      TrainingItemType.phone3222,
      TrainingItemType.phone2322,
    };

    for (final type in phoneTypes) {
      expect(
        LearningMethod.numberPronunciation.supportedItemTypes.contains(type),
        isTrue,
      );
      expect(
        LearningMethod.valueToText.supportedItemTypes.contains(type),
        isFalse,
      );
      expect(
        LearningMethod.textToValue.supportedItemTypes.contains(type),
        isFalse,
      );
      expect(
        LearningMethod.listening.supportedItemTypes.contains(type),
        isFalse,
      );
      expect(
        LearningMethod.phrasePronunciation.supportedItemTypes.contains(type),
        isFalse,
      );
      expect(LearningParams.defaults().targetAccuracy(type), 0.8);
    }
  });
}
