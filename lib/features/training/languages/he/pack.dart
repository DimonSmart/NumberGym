import 'package:flutter/widgets.dart';

import '../../domain/learning_language.dart';
import '../../domain/time_value.dart';
import '../language_pack.dart';
import '../normalization.dart';
import '../number_lexicon.dart';
import '../phrase_template.dart';
import '../time_lexicon.dart';

LanguagePack buildHebrewPack() {
  return LanguagePack(
    language: LearningLanguage.hebrew,
    code: 'he',
    label: 'Hebrew',
    locale: 'he-IL',
    textDirection: TextDirection.rtl,
    numberWordsConverter: _numberToHebrew,
    timeWordsConverter: _timeToHebrew,
    phraseTemplates: _hebrewPhrases,
    numberLexicon: _hebrewLexicon,
    timeLexicon: _hebrewTimeLexicon,
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

const _hebrewQuarter = '\u05e8\u05d1\u05e2';
const _hebrewHalf = '\u05d7\u05e6\u05d9';
const _hebrewPast = '\u05d0\u05d7\u05e8\u05d9';
const _hebrewTo = '\u05dc\u05e4\u05e0\u05d9';

String _timeToHebrew(TimeValue time) {
  final minute = time.minute;
  if (time.hour == 0 && minute == 0) {
    return 'חצות';
  }
  if (time.hour == 12 && minute == 0) {
    return 'צהריים';
  }
  final hourWords = _numberToHebrew(time.hour);
  if (minute == 0) {
    return hourWords;
  }
  if (minute == 15) {
    return '$_hebrewQuarter $_hebrewPast $hourWords';
  }
  if (minute == 30) {
    return '$_hebrewHalf $_hebrewPast $hourWords';
  }
  if (minute == 45) {
    final nextHour = (time.hour + 1) % 24;
    final nextWords = _numberToHebrew(nextHour);
    return '$_hebrewQuarter $_hebrewTo $nextWords';
  }
  final minuteWords = _numberToHebrew(minute);
  return '$hourWords $minuteWords';
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

const _hebrewTimeLexicon = TimeLexicon(
  quarterWords: {_hebrewQuarter},
  halfWords: {_hebrewHalf},
  pastWords: {_hebrewPast},
  toWords: {_hebrewTo},
  oclockWords: {},
  connectorWords: {},
  fillerWords: {},
  specialTimeWords: {'חצות', 'צהריים'},
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
