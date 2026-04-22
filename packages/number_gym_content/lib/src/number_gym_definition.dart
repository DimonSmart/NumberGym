import 'dart:math';

import 'package:trainer_core/trainer_core.dart';

import 'domain/time_value.dart';
import 'languages/language_pack.dart';
import 'languages/registry.dart';
import 'number_gym_matcher_tokenizer.dart';

const _numberGymModuleId = 'number_gym';
const _countryCode = 34;
const _phoneCardsPerFormat = 16;
const _phoneGroupSeparator = ' • ';

const List<ExerciseMode> _numberModes = <ExerciseMode>[
  ExerciseMode.speak,
  ExerciseMode.chooseFromPrompt,
  ExerciseMode.chooseFromAnswer,
  ExerciseMode.listenAndChoose,
  ExerciseMode.reviewPronunciation,
];

const List<ExerciseMode> _timeModes = <ExerciseMode>[
  ExerciseMode.speak,
  ExerciseMode.chooseFromPrompt,
  ExerciseMode.chooseFromAnswer,
  ExerciseMode.listenAndChoose,
];

const List<ExerciseMode> _phoneModes = <ExerciseMode>[ExerciseMode.speak];

TrainingAppDefinition buildNumberGymAppDefinition({required AppConfig config}) {
  return TrainingAppDefinition(
    config: config,
    supportedLanguages: LearningLanguage.values,
    profileOf: (language) => LanguageRegistry.of(language).profile,
    tokenizerOf: (language) =>
        NumberGymMatcherTokenizer(LanguageRegistry.of(language)),
    catalog: ExerciseCatalog(modules: <TrainingModule>[NumberGymModule()]),
  );
}

class NumberGymModule implements TrainingModule {
  NumberGymModule({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<String, TimeValue> _lastRandomTimeByLanguage =
      <String, TimeValue>{};
  final Map<String, int> _lastRandomPhoneByFamily = <String, int>{};

  late final Map<String, ExerciseFamily> _families = <String, ExerciseFamily>{
    'digits': ExerciseFamily(
      moduleId: moduleId,
      id: 'digits',
      label: 'Digits',
      shortLabel: 'Digits',
      difficultyTier: ExerciseDifficultyTier.easy,
      defaultDuration: const Duration(seconds: 10),
      supportedModes: _numberModes,
    ),
    'base': ExerciseFamily(
      moduleId: moduleId,
      id: 'base',
      label: 'Base',
      shortLabel: 'Base',
      difficultyTier: ExerciseDifficultyTier.easy,
      defaultDuration: const Duration(seconds: 15),
      supportedModes: _numberModes,
    ),
    'hundreds': ExerciseFamily(
      moduleId: moduleId,
      id: 'hundreds',
      label: 'Hundreds',
      shortLabel: 'Hundreds',
      difficultyTier: ExerciseDifficultyTier.medium,
      defaultDuration: const Duration(seconds: 15),
      supportedModes: _numberModes,
    ),
    'thousands': ExerciseFamily(
      moduleId: moduleId,
      id: 'thousands',
      label: 'Thousands',
      shortLabel: 'Thousands',
      difficultyTier: ExerciseDifficultyTier.medium,
      defaultDuration: const Duration(seconds: 15),
      supportedModes: _numberModes,
    ),
    'timeExact': ExerciseFamily(
      moduleId: moduleId,
      id: 'timeExact',
      label: 'Time (exact)',
      shortLabel: 'Time exact',
      difficultyTier: ExerciseDifficultyTier.medium,
      defaultDuration: const Duration(seconds: 15),
      supportedModes: _timeModes,
    ),
    'timeQuarter': ExerciseFamily(
      moduleId: moduleId,
      id: 'timeQuarter',
      label: 'Time (quarter)',
      shortLabel: 'Time quarter',
      difficultyTier: ExerciseDifficultyTier.hard,
      defaultDuration: const Duration(seconds: 15),
      supportedModes: _timeModes,
    ),
    'timeHalf': ExerciseFamily(
      moduleId: moduleId,
      id: 'timeHalf',
      label: 'Time (half)',
      shortLabel: 'Time half',
      difficultyTier: ExerciseDifficultyTier.medium,
      defaultDuration: const Duration(seconds: 15),
      supportedModes: _timeModes,
    ),
    'timeRandom': ExerciseFamily(
      moduleId: moduleId,
      id: 'timeRandom',
      label: 'Time (random)',
      shortLabel: 'Time random',
      difficultyTier: ExerciseDifficultyTier.hard,
      defaultDuration: const Duration(seconds: 15),
      supportedModes: _timeModes,
    ),
    'phone33x3': ExerciseFamily(
      moduleId: moduleId,
      id: 'phone33x3',
      label: 'Phone numbers (3-3-3)',
      shortLabel: 'Phone 3-3-3',
      difficultyTier: ExerciseDifficultyTier.hard,
      defaultDuration: const Duration(seconds: 30),
      supportedModes: _phoneModes,
      masteryAccuracy: 0.8,
    ),
    'phone3222': ExerciseFamily(
      moduleId: moduleId,
      id: 'phone3222',
      label: 'Phone numbers (3-2-2-2)',
      shortLabel: 'Phone 3-2-2-2',
      difficultyTier: ExerciseDifficultyTier.hard,
      defaultDuration: const Duration(seconds: 30),
      supportedModes: _phoneModes,
      masteryAccuracy: 0.8,
    ),
    'phone2322': ExerciseFamily(
      moduleId: moduleId,
      id: 'phone2322',
      label: 'Phone numbers (2-3-2-2)',
      shortLabel: 'Phone 2-3-2-2',
      difficultyTier: ExerciseDifficultyTier.hard,
      defaultDuration: const Duration(seconds: 30),
      supportedModes: _phoneModes,
      masteryAccuracy: 0.8,
    ),
  };

  static const List<String> _familyOrder = <String>[
    'digits',
    'base',
    'hundreds',
    'thousands',
    'timeExact',
    'timeQuarter',
    'timeHalf',
    'timeRandom',
    'phone33x3',
    'phone3222',
    'phone2322',
  ];

  @override
  String get moduleId => _numberGymModuleId;

  @override
  String get displayName => 'Number Gym';

  @override
  bool supportsLanguage(LearningLanguage language) {
    try {
      LanguageRegistry.of(language);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) {
    if (!supportsLanguage(language)) {
      return const <ExerciseFamily>[];
    }
    return <ExerciseFamily>[
      for (final familyId in _familyOrder) _families[familyId]!,
    ];
  }

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    if (!supportsLanguage(language)) {
      return const <ExerciseCard>[];
    }

    final pack = LanguageRegistry.of(language);
    final seeds = <_CardSeed>[
      ..._buildNumberSeeds(language),
      ..._buildTimeSeeds(language),
      ..._buildPhoneSeeds(language),
    ];
    final seedsByFamily = <String, List<_CardSeed>>{};
    for (final seed in seeds) {
      seedsByFamily.putIfAbsent(seed.family.id, () => <_CardSeed>[]).add(seed);
    }

    return seeds
        .map((seed) {
          return _materializeSeed(
            seed: seed,
            pack: pack,
            seedsByFamily: seedsByFamily,
            dynamic: false,
          );
        })
        .toList(growable: false);
  }

  List<_CardSeed> _buildNumberSeeds(LearningLanguage language) {
    final seeds = <_CardSeed>[];
    void addRange(String familyId, int from, int to, int step) {
      for (var value = from; value <= to; value += step) {
        final family = _families[familyId]!;
        seeds.add(
          _CardSeed(
            id: ExerciseId(
              moduleId: moduleId,
              familyId: family.id,
              variantId: value.toString(),
            ),
            family: family,
            language: language,
            kind: _SeedKind.number,
            numberValue: value,
          ),
        );
      }
    }

    addRange('digits', 0, 9, 1);
    addRange('base', 10, 99, 1);
    addRange('hundreds', 100, 900, 100);
    addRange('thousands', 1000, 9000, 1000);
    return seeds;
  }

  List<_CardSeed> _buildTimeSeeds(LearningLanguage language) {
    final seeds = <_CardSeed>[];
    for (var hour = 0; hour < 24; hour += 1) {
      seeds.add(
        _timeSeed(
          language: language,
          familyId: 'timeExact',
          value: TimeValue(hour: hour, minute: 0),
        ),
      );
      seeds.add(
        _timeSeed(
          language: language,
          familyId: 'timeHalf',
          value: TimeValue(hour: hour, minute: 30),
        ),
      );
      seeds.add(
        _timeSeed(
          language: language,
          familyId: 'timeQuarter',
          value: TimeValue(hour: hour, minute: 15),
        ),
      );
      seeds.add(
        _timeSeed(
          language: language,
          familyId: 'timeQuarter',
          value: TimeValue(hour: hour, minute: 45),
        ),
      );
    }
    seeds.add(
      _CardSeed(
        id: ExerciseId(
          moduleId: moduleId,
          familyId: 'timeRandom',
          variantId: 'random',
        ),
        family: _families['timeRandom']!,
        language: language,
        kind: _SeedKind.timeRandom,
      ),
    );
    return seeds;
  }

  _CardSeed _timeSeed({
    required LearningLanguage language,
    required String familyId,
    required TimeValue value,
  }) {
    final family = _families[familyId]!;
    return _CardSeed(
      id: ExerciseId(
        moduleId: moduleId,
        familyId: family.id,
        variantId: value.storageKey,
      ),
      family: family,
      language: language,
      kind: _SeedKind.timeStatic,
      timeValue: value,
    );
  }

  List<_CardSeed> _buildPhoneSeeds(LearningLanguage language) {
    final seeds = <_CardSeed>[];
    final seen = <int>{};
    final rng = Random(34034);
    for (var i = 0; i < _phoneCardsPerFormat; i += 1) {
      seeds.add(
        _phoneSeed(
          language: language,
          familyId: 'phone33x3',
          localNumber: _uniquePhoneValue('phone33x3', rng, seen),
        ),
      );
      seeds.add(
        _phoneSeed(
          language: language,
          familyId: 'phone3222',
          localNumber: _uniquePhoneValue('phone3222', rng, seen),
        ),
      );
      seeds.add(
        _phoneSeed(
          language: language,
          familyId: 'phone2322',
          localNumber: _uniquePhoneValue('phone2322', rng, seen),
        ),
      );
    }
    return seeds;
  }

  _CardSeed _phoneSeed({
    required LearningLanguage language,
    required String familyId,
    required int localNumber,
  }) {
    final family = _families[familyId]!;
    return _CardSeed(
      id: ExerciseId(
        moduleId: moduleId,
        familyId: family.id,
        variantId: localNumber.toString(),
      ),
      family: family,
      language: language,
      kind: _SeedKind.phone,
      phoneValue: localNumber,
    );
  }

  ExerciseCard _materializeSeed({
    required _CardSeed seed,
    required LanguagePack pack,
    required Map<String, List<_CardSeed>> seedsByFamily,
    required bool dynamic,
  }) {
    switch (seed.kind) {
      case _SeedKind.number:
        return _buildNumberCard(
          seed: seed,
          pack: pack,
          familySeeds: seedsByFamily[seed.family.id] ?? const <_CardSeed>[],
          dynamic: dynamic,
          dynamicResolver: dynamic
              ? null
              : () => _materializeSeed(
                  seed: seed,
                  pack: pack,
                  seedsByFamily: seedsByFamily,
                  dynamic: true,
                ),
        );
      case _SeedKind.timeStatic:
        return _buildTimeCard(
          seed: seed,
          pack: pack,
          value: seed.timeValue!,
          dynamic: dynamic,
          dynamicResolver: dynamic
              ? null
              : () => _materializeSeed(
                  seed: seed,
                  pack: pack,
                  seedsByFamily: seedsByFamily,
                  dynamic: true,
                ),
        );
      case _SeedKind.timeRandom:
        final value = dynamic
            ? _nextRandomTime(seed.language)
            : const TimeValue(hour: 0, minute: 0);
        return _buildTimeCard(
          seed: seed,
          pack: pack,
          value: value,
          dynamic: dynamic,
          dynamicResolver: dynamic
              ? null
              : () => _materializeSeed(
                  seed: seed,
                  pack: pack,
                  seedsByFamily: seedsByFamily,
                  dynamic: true,
                ),
        );
      case _SeedKind.phone:
        final localNumber = dynamic
            ? _nextRandomPhoneValue(seed)
            : seed.phoneValue!;
        final includePrefix = dynamic
            ? _random.nextBool()
            : (seed.phoneValue!.isEven);
        return _buildPhoneCard(
          seed: seed,
          pack: pack,
          localNumber: localNumber,
          includePrefix: includePrefix,
          dynamicResolver: dynamic
              ? null
              : () => _materializeSeed(
                  seed: seed,
                  pack: pack,
                  seedsByFamily: seedsByFamily,
                  dynamic: true,
                ),
        );
    }
  }

  ExerciseCard _buildNumberCard({
    required _CardSeed seed,
    required LanguagePack pack,
    required List<_CardSeed> familySeeds,
    required bool dynamic,
    required DynamicExerciseResolver? dynamicResolver,
  }) {
    final value = seed.numberValue!;
    final displayText = value.toString();
    final spoken = pack.numberWordsConverter(value);
    final reviewSpec = ReviewPronunciationSpec(
      expectedText: _phraseForValue(value, pack, dynamic: dynamic),
    );

    return ExerciseCard(
      id: seed.id,
      progressId: seed.id,
      family: seed.family,
      language: seed.language,
      displayText: displayText,
      promptText: displayText,
      acceptedAnswers: _uniqueStrings(<String>[displayText, spoken]),
      celebrationText: '$displayText -> $spoken',
      chooseFromPrompt: ChoiceExerciseSpec(
        prompt: displayText,
        correctOption: spoken,
        options: _buildNumberWordOptions(
          currentValue: value,
          correctOption: spoken,
          familySeeds: familySeeds,
          pack: pack,
        ),
      ),
      chooseFromAnswer: ChoiceExerciseSpec(
        prompt: spoken,
        correctOption: displayText,
        options: _buildNumberDisplayOptions(
          currentValue: value,
          correctOption: displayText,
          familySeeds: familySeeds,
        ),
      ),
      listenAndChoose: ListeningExerciseSpec(
        speechText: spoken,
        correctOption: displayText,
        options: _buildNumberDisplayOptions(
          currentValue: value,
          correctOption: displayText,
          familySeeds: familySeeds,
        ),
      ),
      reviewPronunciation: reviewSpec,
      dynamicResolver: dynamicResolver,
    );
  }

  ExerciseCard _buildTimeCard({
    required _CardSeed seed,
    required LanguagePack pack,
    required TimeValue value,
    required bool dynamic,
    required DynamicExerciseResolver? dynamicResolver,
  }) {
    final displayText = value.displayText;
    final spoken = pack.timeWordsConverter(value);
    final promptAliases = _timePromptAliases(pack, value);

    return ExerciseCard(
      id: seed.id,
      progressId: seed.id,
      family: seed.family,
      language: seed.language,
      displayText: displayText,
      promptText: displayText,
      acceptedAnswers: _uniqueStrings(<String>[displayText, spoken]),
      celebrationText: '$displayText -> $spoken',
      matcherConfig: ExerciseMatcherConfig(promptAliases: promptAliases),
      chooseFromPrompt: ChoiceExerciseSpec(
        prompt: displayText,
        correctOption: spoken,
        options: _buildTimeWordOptions(
          currentValue: value,
          correctOption: spoken,
          familyId: seed.family.id,
          pack: pack,
          dynamic: dynamic,
        ),
      ),
      chooseFromAnswer: ChoiceExerciseSpec(
        prompt: spoken,
        correctOption: displayText,
        options: _buildTimeDisplayOptions(
          currentValue: value,
          correctOption: displayText,
          familyId: seed.family.id,
          dynamic: dynamic,
        ),
      ),
      listenAndChoose: ListeningExerciseSpec(
        speechText: spoken,
        correctOption: displayText,
        options: _buildTimeDisplayOptions(
          currentValue: value,
          correctOption: displayText,
          familyId: seed.family.id,
          dynamic: dynamic,
        ),
      ),
      dynamicResolver: dynamicResolver,
    );
  }

  ExerciseCard _buildPhoneCard({
    required _CardSeed seed,
    required LanguagePack pack,
    required int localNumber,
    required bool includePrefix,
    required DynamicExerciseResolver? dynamicResolver,
  }) {
    final groupedLocal = _groupPhoneNumber(seed.family.id, localNumber);
    final prompt = includePrefix
        ? '+$_countryCode $groupedLocal'
        : groupedLocal;
    final compact = groupedLocal.replaceAll(' ', '');
    final spokenPrompt = _spokenPhonePrompt(
      groupedLocal: groupedLocal,
      pack: pack,
      includePrefix: includePrefix,
    );

    return ExerciseCard(
      id: seed.id,
      progressId: seed.id,
      family: seed.family,
      language: seed.language,
      displayText: prompt,
      promptText: prompt,
      acceptedAnswers: _uniqueStrings(<String>[
        prompt,
        spokenPrompt,
        groupedLocal,
        compact,
        if (includePrefix) '+$_countryCode$compact',
        if (includePrefix) '$_countryCode$compact',
      ]),
      celebrationText: '$prompt -> $spokenPrompt',
      dynamicResolver: dynamicResolver,
    );
  }

  List<String> _buildNumberWordOptions({
    required int currentValue,
    required String correctOption,
    required List<_CardSeed> familySeeds,
    required LanguagePack pack,
  }) {
    final distractors = familySeeds
        .where(
          (seed) =>
              seed.numberValue != null && seed.numberValue != currentValue,
        )
        .map((seed) => pack.numberWordsConverter(seed.numberValue!))
        .toList(growable: false);
    return _buildOptions(correctOption, distractors);
  }

  List<String> _buildNumberDisplayOptions({
    required int currentValue,
    required String correctOption,
    required List<_CardSeed> familySeeds,
  }) {
    final distractors = familySeeds
        .where(
          (seed) =>
              seed.numberValue != null && seed.numberValue != currentValue,
        )
        .map((seed) => seed.numberValue!.toString())
        .toList(growable: false);
    return _buildOptions(correctOption, distractors);
  }

  List<String> _buildTimeWordOptions({
    required TimeValue currentValue,
    required String correctOption,
    required String familyId,
    required LanguagePack pack,
    required bool dynamic,
  }) {
    final candidateTimes = _timeCandidatesForOptions(
      familyId: familyId,
      currentValue: currentValue,
      dynamic: dynamic,
    );
    final distractors = candidateTimes
        .map(pack.timeWordsConverter)
        .toList(growable: false);
    return _buildOptions(correctOption, distractors);
  }

  List<String> _buildTimeDisplayOptions({
    required TimeValue currentValue,
    required String correctOption,
    required String familyId,
    required bool dynamic,
  }) {
    final candidateTimes = _timeCandidatesForOptions(
      familyId: familyId,
      currentValue: currentValue,
      dynamic: dynamic,
    );
    final distractors = candidateTimes
        .map((value) => value.displayText)
        .toList(growable: false);
    return _buildOptions(correctOption, distractors);
  }

  List<TimeValue> _timeCandidatesForOptions({
    required String familyId,
    required TimeValue currentValue,
    required bool dynamic,
  }) {
    if (familyId == 'timeRandom') {
      final values = <TimeValue>[];
      while (values.length < 8) {
        final candidate = TimeValue(
          hour: _random.nextInt(24),
          minute: _random.nextInt(60),
        );
        if (candidate == currentValue || values.contains(candidate)) {
          continue;
        }
        values.add(candidate);
      }
      return values;
    }

    return _buildTimeSeeds(LearningLanguage.english)
        .where(
          (seed) =>
              seed.family.id == familyId && seed.timeValue != currentValue,
        )
        .map((seed) => seed.timeValue!)
        .toList(growable: false);
  }

  List<String> _buildOptions(String correctOption, List<String> distractors) {
    final options = <String>[correctOption];
    final seen = <String>{correctOption.trim().toLowerCase()};
    final shuffled = List<String>.from(distractors)..shuffle(_random);
    for (final candidate in shuffled) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      options.add(trimmed);
      if (options.length == 4) {
        break;
      }
    }
    options.shuffle(_random);
    return options;
  }

  List<String> _timePromptAliases(LanguagePack pack, TimeValue value) {
    if (pack.language != LearningLanguage.english || value.minute != 0) {
      return const <String>[];
    }
    return <String>['${value.hour} o clock'];
  }

  String _phraseForValue(
    int value,
    LanguagePack pack, {
    required bool dynamic,
  }) {
    final matching = pack.phraseTemplates
        .where((template) => template.supports(value))
        .toList(growable: false);
    if (matching.isEmpty) {
      return pack.numberWordsConverter(value);
    }
    final template = dynamic
        ? matching[_random.nextInt(matching.length)]
        : matching.first;
    return template.materialize(value);
  }

  TimeValue _nextRandomTime(LearningLanguage language) {
    final key = language.code;
    late TimeValue candidate;
    var attempts = 0;
    do {
      candidate = TimeValue(
        hour: _random.nextInt(24),
        minute: _random.nextInt(60),
      );
      attempts += 1;
    } while (_lastRandomTimeByLanguage[key] == candidate && attempts < 8);
    _lastRandomTimeByLanguage[key] = candidate;
    return candidate;
  }

  int _nextRandomPhoneValue(_CardSeed seed) {
    final key = '${seed.language.code}/${seed.family.id}';
    final previous = _lastRandomPhoneByFamily[key];
    late int candidate;
    var attempts = 0;
    do {
      candidate = _buildRandomPhoneValue(seed.family.id);
      attempts += 1;
    } while (candidate == previous && attempts < 8);
    _lastRandomPhoneByFamily[key] = candidate;
    return candidate;
  }

  int _uniquePhoneValue(String familyId, Random random, Set<int> seen) {
    while (true) {
      final candidate = _buildRandomPhoneValue(familyId, random: random);
      if (seen.add(candidate)) {
        return candidate;
      }
    }
  }

  int _buildRandomPhoneValue(String familyId, {Random? random}) {
    final rng = random ?? _random;
    final firstDigit = switch (familyId) {
      'phone33x3' || 'phone3222' => rng.nextBool() ? 6 : 7,
      'phone2322' => rng.nextBool() ? 8 : 9,
      _ => 6,
    };

    var value = firstDigit;
    for (var i = 0; i < 8; i += 1) {
      value = value * 10 + rng.nextInt(10);
    }
    return value;
  }

  String _groupPhoneNumber(String familyId, int localNumber) {
    final digits = localNumber.toString().padLeft(9, '0');
    final pattern = switch (familyId) {
      'phone33x3' => const <int>[3, 3, 3],
      'phone3222' => const <int>[3, 2, 2, 2],
      'phone2322' => const <int>[2, 3, 2, 2],
      _ => const <int>[3, 3, 3],
    };

    final groups = <String>[];
    var cursor = 0;
    for (final size in pattern) {
      groups.add(digits.substring(cursor, cursor + size));
      cursor += size;
    }
    return groups.join(' ');
  }

  String _spokenPhonePrompt({
    required String groupedLocal,
    required LanguagePack pack,
    required bool includePrefix,
  }) {
    final localWords = groupedLocal
        .split(_spaces)
        .where((group) => group.isNotEmpty)
        .map((group) => _phoneGroupToWords(group, pack.numberWordsConverter))
        .join(_phoneGroupSeparator)
        .trim();

    if (!includePrefix) {
      return localWords;
    }

    final prefixWords = pack.numberWordsConverter(_countryCode);
    if (localWords.isEmpty) {
      return '${_plusWord(pack)} $prefixWords';
    }
    return '${_plusWord(pack)} $prefixWords$_phoneGroupSeparator$localWords';
  }

  String _phoneGroupToWords(String group, NumberWordsConverter converter) {
    if (group.length > 1 && group.startsWith('0')) {
      return group
          .split('')
          .map((digit) => converter(int.parse(digit)))
          .join(' ');
    }

    final value = int.tryParse(group);
    if (value == null) {
      return group
          .split('')
          .map((digit) => converter(int.parse(digit)))
          .join(' ');
    }
    return converter(value);
  }

  String _plusWord(LanguagePack pack) {
    for (final entry in pack.operatorWords.entries) {
      if (entry.value == 'PLUS') {
        return entry.key;
      }
    }
    return 'plus';
  }
}

enum _SeedKind { number, timeStatic, timeRandom, phone }

class _CardSeed {
  const _CardSeed({
    required this.id,
    required this.family,
    required this.language,
    required this.kind,
    this.numberValue,
    this.timeValue,
    this.phoneValue,
  });

  final ExerciseId id;
  final ExerciseFamily family;
  final LearningLanguage language;
  final _SeedKind kind;
  final int? numberValue;
  final TimeValue? timeValue;
  final int? phoneValue;
}

List<String> _uniqueStrings(List<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final key = trimmed.toLowerCase();
    if (seen.add(key)) {
      result.add(trimmed);
    }
  }
  return result;
}

final _spaces = RegExp(r'\s+');
