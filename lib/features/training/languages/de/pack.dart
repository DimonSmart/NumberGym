import 'package:flutter/widgets.dart';

import '../../domain/learning_language.dart';
import '../language_pack.dart';
import '../normalization.dart';
import '../number_lexicon.dart';
import '../phrase_template.dart';

LanguagePack buildGermanPack() {
  return LanguagePack(
    language: LearningLanguage.german,
    code: 'de',
    label: 'German',
    locale: 'de-DE',
    textDirection: TextDirection.ltr,
    numberWordsConverter: _numberToGerman,
    phraseTemplates: _germanPhrases,
    numberLexicon: _germanLexicon,
    operatorWords: _germanOperatorWords,
    ignoredWords: _germanIgnoredWords,
    ttsPreviewText: 'Hallo! Ich bin deine neue Stimme. Wie klinge ich?',
    preferredSpeechLocaleId: 'de_DE',
    normalizer: normalizeLatin,
  );
}

String _numberToGerman(int value) {
  if (value < 0) {
    throw RangeError('Negative numbers not supported');
  }
  if (value < 20) {
    const small = <String>[
      'null',
      'eins',
      'zwei',
      'drei',
      'vier',
      'fünf',
      'sechs',
      'sieben',
      'acht',
      'neun',
      'zehn',
      'elf',
      'zwölf',
      'dreizehn',
      'vierzehn',
      'fünfzehn',
      'sechzehn',
      'siebzehn',
      'achtzehn',
      'neunzehn',
    ];
    return small[value];
  }
  if (value < 100) {
    const tens = <int, String>{
      20: 'zwanzig',
      30: 'dreißig',
      40: 'vierzig',
      50: 'fünfzig',
      60: 'sechzig',
      70: 'siebzig',
      80: 'achtzig',
      90: 'neunzig',
    };
    final tensValue = (value ~/ 10) * 10;
    final ones = value % 10;
    if (ones == 0) return tens[tensValue]!;
    final onesWord = ones == 1 ? 'ein' : _numberToGerman(ones);
    return '${onesWord}und${tens[tensValue]}';
  }
  if (value < 1000) {
    final hundreds = value ~/ 100;
    final remainder = value % 100;
    final prefix =
        hundreds == 1 ? 'einhundert' : '${_numberToGerman(hundreds)}hundert';
    return remainder == 0 ? prefix : '$prefix${_numberToGerman(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    final prefix =
        thousands == 1 ? 'eintausend' : '${_numberToGerman(thousands)}tausend';
    return remainder == 0 ? prefix : '$prefix${_numberToGerman(remainder)}';
  }
  if (value == 1000000) return 'eine Million';

  return value.toString();
}

const _germanLexicon = NumberLexicon(
  units: {
    'null': 0,
    'eins': 1,
    'ein': 1,
    'eine': 1,
    'zwei': 2,
    'drei': 3,
    'vier': 4,
    'funf': 5,
    'sechs': 6,
    'sieben': 7,
    'acht': 8,
    'neun': 9,
    'zehn': 10,
    'elf': 11,
    'zwolf': 12,
    'dreizehn': 13,
    'vierzehn': 14,
    'funfzehn': 15,
    'sechzehn': 16,
    'siebzehn': 17,
    'achtzehn': 18,
    'neunzehn': 19,
  },
  tens: {
    'zwanzig': 20,
    'dreissig': 30,
    'vierzig': 40,
    'funfzig': 50,
    'sechzig': 60,
    'siebzig': 70,
    'achtzig': 80,
    'neunzig': 90,
  },
  scales: {
    'hundert': 100,
    'tausend': 1000,
    'million': 1000000,
    'millionen': 1000000,
  },
  conjunctions: {'und'},
);

const _germanOperatorWords = {
  'plus': 'PLUS',
  'minus': 'MINUS',
  'mal': 'MULTIPLY',
  'multipliziert': 'MULTIPLY',
  'geteilt': 'DIVIDE',
  'durch': 'DIVIDE',
  'gleich': 'EQUALS',
  'ist': 'EQUALS',
  'x': 'MULTIPLY',
};

const _germanIgnoredWords = {
  'bitte',
};

const _germanPhrases = <PhraseTemplate>[
  PhraseTemplate(
    id: 301,
    templateText: 'Mein Opa ist {X} Jahre alt.',
    minValue: 40,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 302,
    templateText: 'Der Akkustand meines Handys liegt bei {X} Prozent.',
    minValue: 0,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 303,
    templateText: 'Ich habe {X} Kilo Äpfel gekauft.',
    minValue: 1,
    maxValue: 10,
  ),
  PhraseTemplate(
    id: 304,
    templateText: 'Das Ticket kostet {X} Euro.',
    minValue: 0,
    maxValue: 1000,
  ),
  PhraseTemplate(
    id: 305,
    templateText: 'Auf dem Konzert sind {X} Leute.',
    minValue: 0,
    maxValue: 10000,
  ),
];
