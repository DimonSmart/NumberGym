import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/languages/registry.dart';

void main() {
  test('numberToEnglish handles edges', () {
    final toWords = LanguageRegistry.of(
      LearningLanguage.english,
    ).numberWordsConverter;
    expect(toWords(0), 'zero');
    expect(toWords(42), 'forty two');
    expect(toWords(100), 'one hundred');
    expect(toWords(101), 'one hundred and one');
  });

  test('numberToSpanish handles edges', () {
    final toWords = LanguageRegistry.of(
      LearningLanguage.spanish,
    ).numberWordsConverter;
    expect(toWords(0), 'cero');
    expect(toWords(16), 'dieciseis');
    expect(toWords(21), 'veintiuno');
    expect(toWords(42), 'cuarenta y dos');
    expect(toWords(100), 'cien');
    expect(toWords(101), 'ciento uno');
  });
}
