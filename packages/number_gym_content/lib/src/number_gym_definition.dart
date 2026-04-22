import 'package:flutter/widgets.dart';
import 'package:trainer_core/trainer_core.dart';

class NumberGymLanguageResources {
  const NumberGymLanguageResources({
    required this.profile,
    required this.numberWords,
    required this.timeWords,
    required this.plusWord,
  });

  final BaseLanguageProfile profile;
  final String Function(int value) numberWords;
  final String Function(TimeValue time) timeWords;
  final String plusWord;
}

class TimeValue implements Comparable<TimeValue> {
  const TimeValue({
    required this.hour,
    required this.minute,
  }) : assert(hour >= 0 && hour <= 23),
       assert(minute >= 0 && minute <= 59);

  final int hour;
  final int minute;

  String get displayText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(TimeValue other) {
    final byHour = hour.compareTo(other.hour);
    if (byHour != 0) {
      return byHour;
    }
    return minute.compareTo(other.minute);
  }
}

TrainingAppDefinition buildNumberGymAppDefinition({required AppConfig config}) {
  const supportedLanguages = <LearningLanguage>[
    LearningLanguage.english,
    LearningLanguage.spanish,
  ];
  final resourcesByLanguage = <LearningLanguage, NumberGymLanguageResources>{
    LearningLanguage.english: NumberGymLanguageResources(
      profile: BaseLanguageProfile(
        language: LearningLanguage.english,
        code: 'en',
        label: 'English',
        locale: 'en-US',
        textDirection: TextDirection.ltr,
        ttsPreviewText: 'one two three',
        preferredSpeechLocaleId: 'en_US',
        normalizer: _normalizeLatin,
      ),
      numberWords: _numberToEnglish,
      timeWords: _timeToEnglish,
      plusWord: 'plus',
    ),
    LearningLanguage.spanish: NumberGymLanguageResources(
      profile: BaseLanguageProfile(
        language: LearningLanguage.spanish,
        code: 'es',
        label: 'Spanish',
        locale: 'es-ES',
        textDirection: TextDirection.ltr,
        ttsPreviewText: 'uno dos tres',
        preferredSpeechLocaleId: 'es_ES',
        normalizer: _normalizeLatin,
      ),
      numberWords: _numberToSpanish,
      timeWords: _timeToSpanish,
      plusWord: 'mas',
    ),
  };

  return TrainingAppDefinition(
    config: config,
    supportedLanguages: supportedLanguages,
    profileOf: (language) => resourcesByLanguage[language]!.profile,
    tokenizerOf: (language) => GenericMatcherTokenizer(
      resourcesByLanguage[language]!.profile.normalizer,
    ),
    catalog: ExerciseCatalog(
      modules: <TrainingModule>[
        NumberGymModule(resourcesByLanguage: resourcesByLanguage),
      ],
    ),
  );
}

class NumberGymModule implements TrainingModule {
  NumberGymModule({required this.resourcesByLanguage});

  final Map<LearningLanguage, NumberGymLanguageResources> resourcesByLanguage;

  static final ExerciseFamily _numbersFamily = ExerciseFamily(
    moduleId: 'numbers',
    id: 'numbers',
    label: 'Numbers',
    shortLabel: 'Numbers',
    difficultyTier: ExerciseDifficultyTier.easy,
    defaultDuration: const Duration(seconds: 18),
    supportedModes: const <ExerciseMode>[
      ExerciseMode.speak,
      ExerciseMode.chooseFromPrompt,
      ExerciseMode.chooseFromAnswer,
      ExerciseMode.listenAndChoose,
    ],
  );

  static final ExerciseFamily _timesFamily = ExerciseFamily(
    moduleId: 'numbers',
    id: 'time',
    label: 'Time',
    shortLabel: 'Time',
    difficultyTier: ExerciseDifficultyTier.medium,
    defaultDuration: const Duration(seconds: 22),
    supportedModes: const <ExerciseMode>[
      ExerciseMode.speak,
      ExerciseMode.chooseFromPrompt,
      ExerciseMode.chooseFromAnswer,
      ExerciseMode.listenAndChoose,
    ],
  );

  static final ExerciseFamily _phonesFamily = ExerciseFamily(
    moduleId: 'numbers',
    id: 'phone',
    label: 'Phone',
    shortLabel: 'Phone',
    difficultyTier: ExerciseDifficultyTier.hard,
    defaultDuration: const Duration(seconds: 26),
    supportedModes: const <ExerciseMode>[
      ExerciseMode.speak,
      ExerciseMode.chooseFromPrompt,
      ExerciseMode.chooseFromAnswer,
      ExerciseMode.listenAndChoose,
    ],
  );

  @override
  String get moduleId => 'numbers';

  @override
  String get displayName => 'Number Gym';

  @override
  bool supportsLanguage(LearningLanguage language) {
    return resourcesByLanguage.containsKey(language);
  }

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) {
    if (!supportsLanguage(language)) {
      return const <ExerciseFamily>[];
    }
    return <ExerciseFamily>[
      _numbersFamily,
      _timesFamily,
      _phonesFamily,
    ];
  }

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    final resources = resourcesByLanguage[language];
    if (resources == null) {
      return const <ExerciseCard>[];
    }

    final seeds = <_SeedCard>[
      ..._buildNumberSeeds(language, resources),
      ..._buildTimeSeeds(language, resources),
      ..._buildPhoneSeeds(language, resources),
    ];

    return seeds.map((seed) {
      return ExerciseCard(
        id: seed.id,
        progressId: seed.id,
        family: seed.family,
        language: language,
        displayText: seed.displayText,
        promptText: seed.canonicalAnswer,
        acceptedAnswers: seed.acceptedAnswers,
        celebrationText: seed.celebrationText,
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: seed.displayText,
          correctOption: seed.canonicalAnswer,
          options: _buildOptions(
            seed: seed,
            allSeeds: seeds,
            valueOf: (candidate) => candidate.canonicalAnswer,
          ),
        ),
        chooseFromAnswer: ChoiceExerciseSpec(
          prompt: seed.canonicalAnswer,
          correctOption: seed.displayText,
          options: _buildOptions(
            seed: seed,
            allSeeds: seeds,
            valueOf: (candidate) => candidate.displayText,
          ),
        ),
        listenAndChoose: ListeningExerciseSpec(
          speechText: seed.audioText,
          correctOption: seed.displayText,
          options: _buildOptions(
            seed: seed,
            allSeeds: seeds,
            valueOf: (candidate) => candidate.displayText,
          ),
        ),
      );
    }).toList(growable: false);
  }

  List<_SeedCard> _buildNumberSeeds(
    LearningLanguage language,
    NumberGymLanguageResources resources,
  ) {
    final values = <int>[
      for (var value = 0; value <= 99; value += 1) value,
      for (var value = 100; value <= 900; value += 100) value,
      for (var value = 1000; value <= 9000; value += 1000) value,
    ];
    return values.map((value) {
      final answer = resources.numberWords(value);
      return _SeedCard(
        id: ExerciseId(
          moduleId: moduleId,
          familyId: _numbersFamily.id,
          variantId: value.toString(),
        ),
        family: _numbersFamily,
        displayText: value.toString(),
        canonicalAnswer: answer,
        acceptedAnswers: _uniqueStrings(<String>[
          answer,
          value.toString(),
        ]),
        celebrationText: '$value -> $answer',
      );
    }).toList(growable: false);
  }

  List<_SeedCard> _buildTimeSeeds(
    LearningLanguage language,
    NumberGymLanguageResources resources,
  ) {
    final values = <TimeValue>[
      for (var hour = 0; hour < 24; hour += 1) TimeValue(hour: hour, minute: 0),
      for (var hour = 0; hour < 24; hour += 1) TimeValue(hour: hour, minute: 15),
      for (var hour = 0; hour < 24; hour += 1) TimeValue(hour: hour, minute: 30),
      for (var hour = 0; hour < 24; hour += 1) TimeValue(hour: hour, minute: 45),
    ]..sort();

    return values.map((time) {
      final answer = resources.timeWords(time);
      return _SeedCard(
        id: ExerciseId(
          moduleId: moduleId,
          familyId: _timesFamily.id,
          variantId: time.displayText,
        ),
        family: _timesFamily,
        displayText: time.displayText,
        canonicalAnswer: answer,
        acceptedAnswers: _uniqueStrings(<String>[
          answer,
          time.displayText,
        ]),
        celebrationText: '${time.displayText} -> $answer',
      );
    }).toList(growable: false);
  }

  List<_SeedCard> _buildPhoneSeeds(
    LearningLanguage language,
    NumberGymLanguageResources resources,
  ) {
    const countryCode = 34;
    final numbers = <String>[
      '612 345 678',
      '623 456 781',
      '634 567 812',
      '645 678 123',
      '656 781 234',
      '667 812 345',
      '678 123 456',
      '689 234 567',
      '712 345 678',
      '723 456 781',
      '734 567 812',
      '745 678 123',
      '812 345 678',
      '823 456 781',
      '934 567 812',
      '945 678 123',
    ];

    return numbers.asMap().entries.map((entry) {
      final grouped = entry.value;
      final compact = grouped.replaceAll(' ', '');
      final withPrefix = entry.key.isEven
          ? '+$countryCode $grouped'
          : grouped;
      final spoken = _spokenPhone(
        groupedLocal: grouped,
        includePrefix: entry.key.isEven,
        countryCode: countryCode,
        plusWord: resources.plusWord,
        numberWords: resources.numberWords,
      );
      return _SeedCard(
        id: ExerciseId(
          moduleId: moduleId,
          familyId: _phonesFamily.id,
          variantId: compact,
        ),
        family: _phonesFamily,
        displayText: withPrefix,
        canonicalAnswer: spoken,
        acceptedAnswers: _uniqueStrings(<String>[
          spoken,
          withPrefix,
          compact,
          grouped,
          if (entry.key.isEven) '$countryCode$compact',
        ]),
        celebrationText: '$withPrefix -> $spoken',
      );
    }).toList(growable: false);
  }

  List<String> _buildOptions({
    required _SeedCard seed,
    required List<_SeedCard> allSeeds,
    required String Function(_SeedCard candidate) valueOf,
  }) {
    final options = <String>[valueOf(seed)];
    for (final candidate in allSeeds) {
      if (candidate.id == seed.id || candidate.family != seed.family) {
        continue;
      }
      final value = valueOf(candidate);
      if (options.contains(value)) {
        continue;
      }
      options.add(value);
      if (options.length == 4) {
        break;
      }
    }
    return options;
  }
}

class _SeedCard {
  const _SeedCard({
    required this.id,
    required this.family,
    required this.displayText,
    required this.canonicalAnswer,
    required this.acceptedAnswers,
    required this.celebrationText,
    String? audioText,
  }) : audioText = audioText ?? canonicalAnswer;

  final ExerciseId id;
  final ExerciseFamily family;
  final String displayText;
  final String canonicalAnswer;
  final List<String> acceptedAnswers;
  final String celebrationText;
  final String audioText;
}

List<String> _uniqueStrings(List<String> values) {
  final unique = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final key = trimmed.toLowerCase();
    if (seen.add(key)) {
      unique.add(trimmed);
    }
  }
  return unique;
}

String _spokenPhone({
  required String groupedLocal,
  required bool includePrefix,
  required int countryCode,
  required String plusWord,
  required String Function(int value) numberWords,
}) {
  final groups = groupedLocal.split(' ');
  final localWords = groups.map((group) {
    if (group.startsWith('0')) {
      return group.split('').map((digit) {
        return numberWords(int.parse(digit));
      }).join(' ');
    }
    return numberWords(int.parse(group));
  }).join(' ');
  if (!includePrefix) {
    return localWords;
  }
  return '$plusWord ${numberWords(countryCode)} $localWords';
}

String _normalizeLatin(String text) {
  final lower = text.trim().toLowerCase();
  if (lower.isEmpty) {
    return '';
  }
  var normalized = lower
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ñ', 'n')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u');
  normalized = normalized.replaceAll(RegExp(r"[^a-z0-9\s'+:.-]"), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}

String _numberToEnglish(int value) {
  if (value < 0) {
    throw RangeError('Negative numbers are not supported.');
  }
  if (value < 20) {
    const words = <String>[
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
    return words[value];
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
    final remainder = value % 10;
    if (remainder == 0) {
      return tens[tensValue]!;
    }
    return '${tens[tensValue]} ${_numberToEnglish(remainder)}';
  }
  if (value < 1000) {
    final hundreds = value ~/ 100;
    final remainder = value % 100;
    if (remainder == 0) {
      return '${_numberToEnglish(hundreds)} hundred';
    }
    return '${_numberToEnglish(hundreds)} hundred ${_numberToEnglish(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    if (remainder == 0) {
      return '${_numberToEnglish(thousands)} thousand';
    }
    return '${_numberToEnglish(thousands)} thousand ${_numberToEnglish(remainder)}';
  }
  return value.toString();
}

String _numberToSpanish(int value) {
  if (value < 0) {
    throw RangeError('Negative numbers are not supported.');
  }
  if (value < 30) {
    const words = <String>[
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
    return words[value];
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
    final remainder = value % 10;
    if (remainder == 0) {
      return tens[tensValue]!;
    }
    return '${tens[tensValue]} y ${_numberToSpanish(remainder)}';
  }
  if (value == 100) {
    return 'cien';
  }
  if (value < 1000) {
    final hundreds = value ~/ 100;
    final remainder = value % 100;
    const hundredsWords = <int, String>{
      1: 'ciento',
      2: 'doscientos',
      3: 'trescientos',
      4: 'cuatrocientos',
      5: 'quinientos',
      6: 'seiscientos',
      7: 'setecientos',
      8: 'ochocientos',
      9: 'novecientos',
    };
    final prefix = hundredsWords[hundreds]!;
    if (remainder == 0) {
      return prefix;
    }
    return '$prefix ${_numberToSpanish(remainder)}';
  }
  if (value < 1000000) {
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    final prefix = thousands == 1 ? 'mil' : '${_numberToSpanish(thousands)} mil';
    if (remainder == 0) {
      return prefix;
    }
    return '$prefix ${_numberToSpanish(remainder)}';
  }
  return value.toString();
}

String _timeToEnglish(TimeValue time) {
  if (time.hour == 0 && time.minute == 0) {
    return 'midnight';
  }
  if (time.hour == 12 && time.minute == 0) {
    return 'noon';
  }
  final hourWords = _numberToEnglish(time.hour);
  if (time.minute == 0) {
    return '$hourWords o clock';
  }
  if (time.minute == 15) {
    return 'quarter past $hourWords';
  }
  if (time.minute == 30) {
    return 'half past $hourWords';
  }
  if (time.minute == 45) {
    return 'quarter to ${_numberToEnglish((time.hour + 1) % 24)}';
  }
  return '$hourWords ${_numberToEnglish(time.minute)}';
}

String _timeToSpanish(TimeValue time) {
  if (time.hour == 0 && time.minute == 0) {
    return 'medianoche';
  }
  if (time.hour == 12 && time.minute == 0) {
    return 'mediodia';
  }
  final hourWords = _numberToSpanish(time.hour);
  if (time.minute == 0) {
    return '$hourWords en punto';
  }
  if (time.minute == 15) {
    return '$hourWords y cuarto';
  }
  if (time.minute == 30) {
    return '$hourWords y media';
  }
  if (time.minute == 45) {
    return '${_numberToSpanish((time.hour + 1) % 24)} menos cuarto';
  }
  return '$hourWords ${_numberToSpanish(time.minute)}';
}
