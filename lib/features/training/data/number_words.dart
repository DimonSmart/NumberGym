String numberToEnglish(int value) {
  if (value < 0 || value > 100) {
    throw RangeError('Supported range is 0..100');
  }

  if (value == 100) return 'one hundred';

  const small = <String>[
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'thirteen',
    'fourteen',
    'fifteen',
    'sixteen',
    'seventeen',
    'eighteen',
    'nineteen',
  ];

  if (value < 20) return small[value];

  const tens = <int, String>{
    20: 'twenty',
    30: 'thirty',
    40: 'forty',
    50: 'fifty',
    60: 'sixty',
    70: 'seventy',
    80: 'eighty',
    90: 'ninety',
  };

  final tensValue = (value ~/ 10) * 10;
  final ones = value % 10;
  final tensWord = tens[tensValue]!;
  if (ones == 0) return tensWord;
  return '$tensWord ${small[ones]}';
}

String numberToSpanish(int value) {
  if (value < 0 || value > 100) {
    throw RangeError('Supported range is 0..100');
  }

  if (value == 100) return 'cien';

  const upTo29 = <String>[
    'cero',
    'uno',
    'dos',
    'tres',
    'cuatro',
    'cinco',
    'seis',
    'siete',
    'ocho',
    'nueve',
    'diez',
    'once',
    'doce',
    'trece',
    'catorce',
    'quince',
    'dieciseis',
    'diecisiete',
    'dieciocho',
    'diecinueve',
    'veinte',
    'veintiuno',
    'veintidos',
    'veintitres',
    'veinticuatro',
    'veinticinco',
    'veintiseis',
    'veintisiete',
    'veintiocho',
    'veintinueve',
  ];

  if (value < 30) return upTo29[value];

  const tens = <int, String>{
    30: 'treinta',
    40: 'cuarenta',
    50: 'cincuenta',
    60: 'sesenta',
    70: 'setenta',
    80: 'ochenta',
    90: 'noventa',
  };

  final tensValue = (value ~/ 10) * 10;
  final ones = value % 10;
  final tensWord = tens[tensValue]!;
  if (ones == 0) return tensWord;
  return '$tensWord y ${upTo29[ones]}';
}
