import 'package:flutter/widgets.dart';

import '../../domain/learning_language.dart';
import '../language_pack.dart';
import '../normalization.dart';
import '../number_lexicon.dart';
import '../phrase_template.dart';

LanguagePack buildHebrewPack() {
  return LanguagePack(
    language: LearningLanguage.hebrew,
    code: 'he',
    label: 'Hebrew',
    locale: 'he-IL',
    textDirection: TextDirection.rtl,
    numberWordsConverter: _numberToHebrew,
    phraseTemplates: _hebrewPhrases,
    numberLexicon: _hebrewLexicon,
    operatorWords: _hebrewOperatorWords,
    ignoredWords: _hebrewIgnoredWords,
    ttsPreviewText: 'היי! אני הקול החדש שלך. איך אני נשמע?',
    preferredSpeechLocaleId: 'he_IL',
    normalizer: normalizeHebrew,
  );
}

String _numberToHebrew(int value) {
  if (value < 0) {
    throw RangeError('Negative numbers not supported');
  }
  if (value < 20) {
    const small = <String>[
      'אפס',
      'אחד',
      'שניים',
      'שלוש',
      'ארבע',
      'חמש',
      'שש',
      'שבע',
      'שמונה',
      'תשע',
      'עשר',
      'אחד עשר',
      'שנים עשר',
      'שלושה עשר',
      'ארבעה עשר',
      'חמישה עשר',
      'שישה עשר',
      'שבעה עשר',
      'שמונה עשר',
      'תשעה עשר',
    ];
    return small[value];
  }
  if (value < 100) {
    const tens = <int, String>{
      20: 'עשרים',
      30: 'שלושים',
      40: 'ארבעים',
      50: 'חמישים',
      60: 'שישים',
      70: 'שבעים',
      80: 'שמונים',
      90: 'תשעים',
    };
    final tensValue = (value ~/ 10) * 10;
    final ones = value % 10;
    if (ones == 0) return tens[tensValue]!;
    return '${tens[tensValue]} ו${_numberToHebrew(ones)}';
  }
  if (value < 1000) {
    const hundreds = <int, String>{
      100: 'מאה',
      200: 'מאתיים',
      300: 'שלוש מאות',
      400: 'ארבע מאות',
      500: 'חמש מאות',
      600: 'שש מאות',
      700: 'שבע מאות',
      800: 'שמונה מאות',
      900: 'תשע מאות',
    };
    final hundredsValue = (value ~/ 100) * 100;
    final remainder = value % 100;
    final prefix = hundreds[hundredsValue]!;
    return remainder == 0 ? prefix : '$prefix ${_numberToHebrew(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    final prefix = switch (thousands) {
      1 => 'אלף',
      2 => 'אלפיים',
      _ => '${_numberToHebrew(thousands)} אלף',
    };
    return remainder == 0 ? prefix : '$prefix ${_numberToHebrew(remainder)}';
  }
  if (value == 1000000) return 'מיליון';

  return value.toString();
}

const _hebrewLexicon = NumberLexicon(
  units: {
    'אפס': 0,
    'אחד': 1,
    'אחת': 1,
    'שניים': 2,
    'שתיים': 2,
    'שנים': 2,
    'שלוש': 3,
    'שלושה': 3,
    'ארבע': 4,
    'ארבעה': 4,
    'חמש': 5,
    'חמישה': 5,
    'שש': 6,
    'שישה': 6,
    'שבע': 7,
    'שבעה': 7,
    'שמונה': 8,
    'תשע': 9,
    'תשעה': 9,
    'עשר': 10,
    'עשרה': 10,
    'מאתיים': 200,
    'אלפיים': 2000,
  },
  tens: {
    'עשרים': 20,
    'שלושים': 30,
    'ארבעים': 40,
    'חמישים': 50,
    'שישים': 60,
    'שבעים': 70,
    'שמונים': 80,
    'תשעים': 90,
  },
  scales: {
    'מאה': 100,
    'אלף': 1000,
    'אלפים': 1000,
    'מיליון': 1000000,
    'מיליונים': 1000000,
  },
  conjunctions: {'ו'},
);

const _hebrewOperatorWords = {
  'פלוס': 'PLUS',
  'מינוס': 'MINUS',
  'כפול': 'MULTIPLY',
  'חלקי': 'DIVIDE',
  'שווה': 'EQUALS',
  'זה': 'EQUALS',
  'x': 'MULTIPLY',
};

const _hebrewIgnoredWords = {
  'בבקשה',
};

const _hebrewPhrases = <PhraseTemplate>[
  PhraseTemplate(
    id: 401,
    templateText: 'סבא שלי בן {X} שנים.',
    minValue: 40,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 402,
    templateText: 'הסוללה של הטלפון שלי על {X} אחוז.',
    minValue: 0,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 403,
    templateText: 'קניתי {X} קילו תפוחים.',
    minValue: 1,
    maxValue: 10,
  ),
  PhraseTemplate(
    id: 404,
    templateText: 'הכרטיס עולה {X} יורו.',
    minValue: 0,
    maxValue: 1000,
  ),
  PhraseTemplate(
    id: 405,
    templateText: 'בהופעה יש {X} אנשים.',
    minValue: 0,
    maxValue: 10000,
  ),
];
