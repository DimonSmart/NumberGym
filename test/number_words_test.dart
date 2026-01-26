import 'package:flutter_test/flutter_test.dart';

import 'package:number_gym/features/training/data/number_words.dart';

void main() {
  test('numberToEnglish handles edges', () {
    expect(numberToEnglish(0), 'zero');
    expect(numberToEnglish(42), 'forty two');
    expect(numberToEnglish(100), 'one hundred');
    expect(numberToEnglish(101), 'one hundred and one');
  });

  test('numberToSpanish handles edges', () {
    expect(numberToSpanish(0), 'cero');
    expect(numberToSpanish(16), 'dieciseis');
    expect(numberToSpanish(21), 'veintiuno');
    expect(numberToSpanish(42), 'cuarenta y dos');
    expect(numberToSpanish(100), 'cien');
    expect(numberToSpanish(101), 'ciento uno');
  });
}
