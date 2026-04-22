import 'package:flutter/widgets.dart';

import '../../domain/learning_language.dart';
import '../../domain/time_value.dart';
import '../language_pack.dart';
import '../normalization.dart';
import '../number_lexicon.dart';
import '../phrase_template.dart';
import '../time_lexicon.dart';

LanguagePack buildSpanishPack() {
  return LanguagePack(
    language: LearningLanguage.spanish,
    code: 'es',
    label: 'Spanish',
    locale: 'es-ES',
    textDirection: TextDirection.ltr,
    numberWordsConverter: _numberToSpanish,
    timeWordsConverter: _timeToSpanish,
    phraseTemplates: _spanishPhrases,
    numberLexicon: _spanishLexicon,
    timeLexicon: _spanishTimeLexicon,
    operatorWords: _spanishOperatorWords,
    ignoredWords: _spanishIgnoredWords,
    ttsPreviewText: '¡Hola! Soy tu voz nueva. ¿Qué tal sueno?',
    preferredSpeechLocaleId: null,
    normalizer: normalizeLatin,
  );
}

String _numberToSpanish(int value) {
  if (value < 0) throw RangeError('Negative numbers not supported');

  if (value < 30) {
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
    return upTo29[value];
  }
  if (value < 100) {
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
    return ones == 0
        ? tens[tensValue]!
        : '${tens[tensValue]} y ${_numberToSpanish(ones)}';
  }
  if (value == 100) return 'cien';
  if (value < 1000) {
    final hundreds = value ~/ 100;
    final remainder = value % 100;
    String prefix;
    switch (hundreds) {
      case 1:
        prefix = 'ciento';
        break;
      case 5:
        prefix = 'quinientos';
        break;
      case 7:
        prefix = 'setecientos';
        break;
      case 9:
        prefix = 'novecientos';
        break;
      default:
        prefix = '${_numberToSpanish(hundreds)}cientos'.replaceAll(
          'unocientos',
          'cientos',
        );
    }
    const hundredsMap = {
      2: 'doscientos',
      3: 'trescientos',
      4: 'cuatrocientos',
      5: 'quinientos',
      6: 'seiscientos',
      7: 'setecientos',
      8: 'ochocientos',
      9: 'novecientos',
    };
    if (hundreds > 1) prefix = hundredsMap[hundreds]!;

    return remainder == 0 ? prefix : '$prefix ${_numberToSpanish(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    final prefix = thousands == 1
        ? 'mil'
        : '${_numberToSpanish(thousands)} mil';
    return remainder == 0 ? prefix : '$prefix ${_numberToSpanish(remainder)}';
  }
  if (value == 1000000) return 'un millón';

  return value.toString();
}

String _timeToSpanish(TimeValue time) {
  final minute = time.minute;
  if (time.hour == 0 && minute == 0) {
    return 'medianoche';
  }
  if (time.hour == 12 && minute == 0) {
    return 'mediodia';
  }
  final hourWords = _numberToSpanish(time.hour);
  if (minute == 0) {
    return '$hourWords en punto';
  }
  if (minute == 15) {
    return '$hourWords y cuarto';
  }
  if (minute == 30) {
    return '$hourWords y media';
  }
  if (minute == 45) {
    final nextHour = (time.hour + 1) % 24;
    if (nextHour == 0) {
      return 'medianoche menos cuarto';
    }
    return '${_numberToSpanish(nextHour)} menos cuarto';
  }
  final minuteWords = _numberToSpanish(minute);
  return '$hourWords $minuteWords';
}

const _spanishLexicon = NumberLexicon(
  units: {
    'cero': 0,
    'uno': 1,
    'un': 1,
    'una': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintidos': 22,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
  },
  tens: {
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
  },
  scales: {
    'cien': 100,
    'ciento': 100,
    'mil': 1000,
    'millon': 1000000,
    'millones': 1000000,
  },
  conjunctions: {'y'},
);

const _spanishTimeLexicon = TimeLexicon(
  quarterWords: {'cuarto'},
  halfWords: {'media'},
  pastWords: {'pasadas'},
  toWords: {'menos'},
  oclockWords: {'punto'},
  connectorWords: {'y'},
  fillerWords: {'en', 'la', 'las'},
  specialTimeWords: {'medianoche', 'mediodia'},
);

const _spanishOperatorWords = {
  'mas': 'PLUS',
  'menos': 'MINUS',
  'por': 'MULTIPLY',
  'dividido': 'DIVIDE',
  'igual': 'EQUALS',
  'es': 'EQUALS',
  'x': 'MULTIPLY',
};

const _spanishIgnoredWords = {'porfavor', 'favor'};

const _spanishPhrases = <PhraseTemplate>[
  PhraseTemplate(
    id: 101,
    templateText: 'Mi abuelo tiene {X} años.',
    minValue: 40,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 102,
    templateText: 'La batería del móvil está al {X} por ciento.',
    minValue: 0,
    maxValue: 100,
  ),
  PhraseTemplate(
    id: 103,
    templateText: 'Compré {X} kilos de manzanas.',
    minValue: 1,
    maxValue: 10,
  ),
  PhraseTemplate(
    id: 104,
    templateText: 'La entrada cuesta {X} euros.',
    minValue: 0,
    maxValue: 1000,
  ),
  PhraseTemplate(
    id: 105,
    templateText: 'En el concierto hay {X} personas.',
    minValue: 0,
    maxValue: 10000,
  ),
];
