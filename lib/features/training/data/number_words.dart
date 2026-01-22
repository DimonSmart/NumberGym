String numberToEnglish(int value) {
  if (value < 0) {
    throw RangeError('Negative numbers not supported');
  }
  if (value < 20) {
    const small = <String>[
      'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
      'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
      'seventeen', 'eighteen', 'nineteen',
    ];
    return small[value];
  }
  if (value < 100) {
    const tens = <int, String>{
      20: 'twenty', 30: 'thirty', 40: 'forty', 50: 'fifty',
      60: 'sixty', 70: 'seventy', 80: 'eighty', 90: 'ninety',
    };
    final tensValue = (value ~/ 10) * 10;
    final ones = value % 10;
    return ones == 0 ? tens[tensValue]! : '${tens[tensValue]} ${numberToEnglish(ones)}';
  }
  if (value < 1000) {
    final hundreds = value ~/ 100;
    final remainder = value % 100;
    return remainder == 0
        ? '${numberToEnglish(hundreds)} hundred'
        : '${numberToEnglish(hundreds)} hundred and ${numberToEnglish(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    return remainder == 0
        ? '${numberToEnglish(thousands)} thousand'
        : '${numberToEnglish(thousands)} thousand ${numberToEnglish(remainder)}'; // "one thousand one", or "one thousand and one"? usually omit "and" for >1000 in simple converts or keep it. Simplest is recursive.
    // "1000" -> "one thousand"
    // "1001" -> "one thousand one"
  }
  if (value == 1000000) return 'one million';
  
  return value.toString(); // Fallback for > 1M or unexpected
}

String numberToSpanish(int value) {
  if (value < 0) throw RangeError('Negative numbers not supported');
  
  if (value < 30) {
    const upTo29 = <String>[
      'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve',
      'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciseis', 'diecisiete',
      'dieciocho', 'diecinueve', 'veinte', 'veintiuno', 'veintidos', 'veintitres',
      'veinticuatro', 'veinticinco', 'veintiseis', 'veintisiete', 'veintiocho', 'veintinueve',
    ];
    return upTo29[value];
  }
  if (value < 100) {
    const tens = <int, String>{
      30: 'treinta', 40: 'cuarenta', 50: 'cincuenta', 60: 'sesenta',
      70: 'setenta', 80: 'ochenta', 90: 'noventa',
    };
    final tensValue = (value ~/ 10) * 10;
    final ones = value % 10;
    return ones == 0 ? tens[tensValue]! : '${tens[tensValue]} y ${numberToSpanish(ones)}';
  }
  if (value == 100) return 'cien';
  if (value < 1000) {
    final hundreds = value ~/ 100;
    final remainder = value % 100;
    String prefix;
    switch (hundreds) {
      case 1: prefix = 'ciento'; break;
      case 5: prefix = 'quinientos'; break;
      case 7: prefix = 'setecientos'; break;
      case 9: prefix = 'novecientos'; break;
      default: prefix = '${numberToSpanish(hundreds)}cientos'.replaceAll('unocientos', 'cientos'); // fix for logic if needed, but simpler map is better.
    }
    // Hardcode hundreds map for correctness
    const hundredsMap = {
      2: 'doscientos', 3: 'trescientos', 4: 'cuatrocientos', 5: 'quinientos',
      6: 'seiscientos', 7: 'setecientos', 8: 'ochocientos', 9: 'novecientos',
    };
    if (hundreds > 1) prefix = hundredsMap[hundreds]!;
    
    return remainder == 0 ? prefix : '$prefix ${numberToSpanish(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    final prefix = thousands == 1 ? 'mil' : '${numberToSpanish(thousands)} mil';
    return remainder == 0 ? prefix : '$prefix ${numberToSpanish(remainder)}';
  }
  if (value == 1000000) return 'un millón';

  return value.toString();
}
