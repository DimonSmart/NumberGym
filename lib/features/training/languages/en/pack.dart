import 'package:flutter/widgets.dart';

import '../../domain/learning_language.dart';
import '../../domain/time_value.dart';
import '../language_pack.dart';
import '../normalization.dart';
import '../number_lexicon.dart';
import '../phrase_template.dart';
import '../time_lexicon.dart';

LanguagePack buildEnglishPack() {
  return LanguagePack(
    language: LearningLanguage.english,
    code: 'en',
    label: 'English',
    locale: 'en-US',
    textDirection: TextDirection.ltr,
    numberWordsConverter: _numberToEnglish,
    timeWordsConverter: _timeToEnglish,
    phraseTemplates: _englishPhrases,
    numberLexicon: _englishLexicon,
    timeLexicon: _englishTimeLexicon,
    operatorWords: _englishOperatorWords,
    ignoredWords: _englishIgnoredWords,
    ttsPreviewText: 'Hi! I’m your new voice. How do I sound?',
    preferredSpeechLocaleId: 'en_US',
    normalizer: normalizeLatin,
  );
}

String _numberToEnglish(int value) {
  if (value < 0) {
    throw RangeError('Negative numbers not supported');
  }
  if (value < 20) {
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
    return small[value];
  }
  if (value < 100) {
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
    return ones == 0
        ? tens[tensValue]!
        : '${tens[tensValue]} ${_numberToEnglish(ones)}';
  }
  if (value < 1000) {
    final hundreds = value ~/ 100;
    final remainder = value % 100;
    return remainder == 0
        ? '${_numberToEnglish(hundreds)} hundred'
        : '${_numberToEnglish(hundreds)} hundred and ${_numberToEnglish(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    return remainder == 0
        ? '${_numberToEnglish(thousands)} thousand'
        : '${_numberToEnglish(thousands)} thousand ${_numberToEnglish(remainder)}';
  }
  if (value == 1000000) return 'one million';

  return value.toString();
}

String _timeToEnglish(TimeValue time) {
  final minute = time.minute;
  if (time.hour == 0 && minute == 0) {
    return 'midnight';
  }
  if (time.hour == 12 && minute == 0) {
    return 'noon';
  }
  final hourWords = _numberToEnglish(time.hour);
  if (minute == 0) {
    return '$hourWords o clock';
  }
  if (minute == 15) {
    return 'quarter past $hourWords';
  }
  if (minute == 30) {
    return 'half past $hourWords';
  }
  if (minute == 45) {
    final nextHour = (time.hour + 1) % 24;
    return 'quarter to ${_numberToEnglish(nextHour)}';
  }
  final minuteWords = _numberToEnglish(minute);
  return '$hourWords $minuteWords';
}

const _englishLexicon = NumberLexicon(
  units: {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
  },
  tens: {
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  },
  scales: {
    'hundred': 100,
    'thousand': 1000,
    'million': 1000000,
  },
  conjunctions: {'and'},
);

const _englishTimeLexicon = TimeLexicon(
  quarterWords: {'quarter'},
  halfWords: {'half'},
  pastWords: {'past'},
  toWords: {'to'},
  oclockWords: {'clock', 'oclock'},
  connectorWords: {'and'},
  fillerWords: {'a', 'the', 'o'},
  specialTimeWords: {'midnight', 'noon', 'midday'},
);

const _englishOperatorWords = {
  'plus': 'PLUS',
  'add': 'PLUS',
  'added': 'PLUS',
  'sum': 'PLUS',
  'minus': 'MINUS',
  'subtract': 'MINUS',
  'subtracted': 'MINUS',
  'times': 'MULTIPLY',
  'multiply': 'MULTIPLY',
  'multiplied': 'MULTIPLY',
  'divide': 'DIVIDE',
  'divided': 'DIVIDE',
  'over': 'DIVIDE',
  'equal': 'EQUALS',
  'equals': 'EQUALS',
  'is': 'EQUALS',
  'x': 'MULTIPLY',
};

const _englishIgnoredWords = {
  'um',
  'uh',
  'erm',
  'ah',
  'eh',
  'please',
};

const _englishPhrases = <PhraseTemplate>[
  PhraseTemplate(
    id: 1,
    templateText: 'My grandpa is {X} years old.',
    minValue: 40,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 2,
    templateText: 'My phone battery is at {X} percent.',
    minValue: 0,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 3,
    templateText: 'I bought {X} kilos of apples.',
    minValue: 1,
    maxValue: 10,
  ),
  PhraseTemplate(
    id: 4,
    templateText: 'The ticket costs {X} euros.',
    minValue: 0,
    maxValue: 1000,
  ),
  PhraseTemplate(
    id: 5,
    templateText: 'There are {X} people at the concert.',
    minValue: 0,
    maxValue: 10000,
  ),
];
