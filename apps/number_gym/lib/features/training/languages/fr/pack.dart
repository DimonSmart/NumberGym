import 'package:flutter/widgets.dart';

import '../../domain/learning_language.dart';
import '../../domain/time_value.dart';
import '../language_pack.dart';
import '../normalization.dart';
import '../number_lexicon.dart';
import '../phrase_template.dart';
import '../time_lexicon.dart';

LanguagePack buildFrenchPack() {
  return LanguagePack(
    language: LearningLanguage.french,
    code: 'fr',
    label: 'French',
    locale: 'fr-FR',
    textDirection: TextDirection.ltr,
    numberWordsConverter: _numberToFrench,
    timeWordsConverter: _timeToFrench,
    phraseTemplates: _frenchPhrases,
    numberLexicon: _frenchLexicon,
    timeLexicon: _frenchTimeLexicon,
    operatorWords: _frenchOperatorWords,
    ignoredWords: _frenchIgnoredWords,
    ttsPreviewText: 'Salut ! Je suis ta nouvelle voix. Ça te va ?',
    preferredSpeechLocaleId: 'fr_FR',
    normalizer: normalizeLatin,
  );
}

String _numberToFrench(int value) {
  if (value < 0) {
    throw RangeError('Negative numbers not supported');
  }
  if (value < 17) {
    const small = <String>[
      'zero',
      'un',
      'deux',
      'trois',
      'quatre',
      'cinq',
      'six',
      'sept',
      'huit',
      'neuf',
      'dix',
      'onze',
      'douze',
      'treize',
      'quatorze',
      'quinze',
      'seize',
    ];
    return small[value];
  }
  if (value < 20) {
    return 'dix ${_numberToFrench(value - 10)}';
  }
  if (value < 70) {
    const tens = <int, String>{
      20: 'vingt',
      30: 'trente',
      40: 'quarante',
      50: 'cinquante',
      60: 'soixante',
    };
    final tensValue = (value ~/ 10) * 10;
    final ones = value % 10;
    if (ones == 0) return tens[tensValue]!;
    if (ones == 1) return '${tens[tensValue]} et un';
    return '${tens[tensValue]} ${_numberToFrench(ones)}';
  }
  if (value < 80) {
    final remainder = value - 60;
    if (remainder == 11) return 'soixante et onze';
    return 'soixante ${_numberToFrench(remainder)}';
  }
  if (value < 100) {
    final remainder = value - 80;
    if (remainder == 0) return 'quatre vingt';
    if (remainder == 1) return 'quatre vingt un';
    return 'quatre vingt ${_numberToFrench(remainder)}';
  }
  if (value < 1000) {
    final hundreds = value ~/ 100;
    final remainder = value % 100;
    final prefix = hundreds == 1 ? 'cent' : '${_numberToFrench(hundreds)} cent';
    return remainder == 0 ? prefix : '$prefix ${_numberToFrench(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    final prefix = thousands == 1
        ? 'mille'
        : '${_numberToFrench(thousands)} mille';
    return remainder == 0 ? prefix : '$prefix ${_numberToFrench(remainder)}';
  }
  if (value == 1000000) return 'un million';

  return value.toString();
}

String _timeToFrench(TimeValue time) {
  final minute = time.minute;
  if (time.hour == 0 && minute == 0) {
    return 'minuit';
  }
  if (time.hour == 12 && minute == 0) {
    return 'midi';
  }
  final hourWords = time.hour == 1 ? 'une' : _numberToFrench(time.hour);
  final hourLabel = time.hour == 1 ? 'heure' : 'heures';
  if (minute == 0) {
    return '$hourWords $hourLabel';
  }
  if (minute == 15) {
    return '$hourWords $hourLabel et quart';
  }
  if (minute == 30) {
    return '$hourWords $hourLabel et demie';
  }
  if (minute == 45) {
    final nextHour = (time.hour + 1) % 24;
    if (nextHour == 0) {
      return 'minuit moins le quart';
    }
    final nextWords = nextHour == 1 ? 'une' : _numberToFrench(nextHour);
    final nextLabel = nextHour == 1 ? 'heure' : 'heures';
    return '$nextWords $nextLabel moins le quart';
  }
  final minuteWords = _numberToFrench(minute);
  return '$hourWords $hourLabel $minuteWords';
}

const _frenchLexicon = NumberLexicon(
  units: {
    'zero': 0,
    'un': 1,
    'une': 1,
    'deux': 2,
    'trois': 3,
    'quatre': 4,
    'cinq': 5,
    'six': 6,
    'sept': 7,
    'huit': 8,
    'neuf': 9,
    'dix': 10,
    'onze': 11,
    'douze': 12,
    'treize': 13,
    'quatorze': 14,
    'quinze': 15,
    'seize': 16,
  },
  tens: {
    'vingt': 20,
    'vingts': 20,
    'trente': 30,
    'quarante': 40,
    'cinquante': 50,
    'soixante': 60,
  },
  scales: {'cent': 100, 'mille': 1000, 'million': 1000000, 'millions': 1000000},
  conjunctions: {'et'},
);

const _frenchTimeLexicon = TimeLexicon(
  quarterWords: {'quart'},
  halfWords: {'demie', 'demi'},
  pastWords: {'apres'},
  toWords: {'moins'},
  oclockWords: {'heure', 'heures'},
  connectorWords: {'et'},
  fillerWords: {'le', 'la', 'les'},
  specialTimeWords: {'minuit', 'midi'},
);

const _frenchOperatorWords = {
  'plus': 'PLUS',
  'moins': 'MINUS',
  'fois': 'MULTIPLY',
  'multiplie': 'MULTIPLY',
  'divise': 'DIVIDE',
  'egal': 'EQUALS',
  'est': 'EQUALS',
  'x': 'MULTIPLY',
};

const _frenchIgnoredWords = {'svp'};

const _frenchPhrases = <PhraseTemplate>[
  PhraseTemplate(
    id: 201,
    templateText: 'Mon grand-pere a {X} ans.',
    minValue: 40,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 202,
    templateText: 'La batterie de mon telephone est a {X} pour cent.',
    minValue: 0,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 203,
    templateText: "J'ai achete {X} kilos de pommes.",
    minValue: 1,
    maxValue: 10,
  ),
  PhraseTemplate(
    id: 204,
    templateText: 'Le billet coute {X} euros.',
    minValue: 0,
    maxValue: 1000,
  ),
  PhraseTemplate(
    id: 205,
    templateText: 'Il y a {X} personnes au concert.',
    minValue: 0,
    maxValue: 10000,
  ),
];
