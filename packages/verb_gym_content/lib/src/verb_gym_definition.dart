import 'package:flutter/widgets.dart';
import 'package:trainer_core/trainer_core.dart';

TrainingAppDefinition buildVerbGymAppDefinition({required AppConfig config}) {
  const supportedLanguages = <LearningLanguage>[
    LearningLanguage.english,
    LearningLanguage.spanish,
  ];
  final resourcesByLanguage = <LearningLanguage, _VerbLanguageResources>{
    LearningLanguage.english: _VerbLanguageResources(
      profile: BaseLanguageProfile(
        language: LearningLanguage.english,
        code: 'en',
        label: 'English',
        locale: 'en-US',
        textDirection: TextDirection.ltr,
        ttsPreviewText: 'I will go',
        preferredSpeechLocaleId: 'en_US',
        normalizer: _normalizeLatin,
      ),
      tenseLabels: const <_VerbTense, String>{
        _VerbTense.present: 'present',
        _VerbTense.past: 'past',
        _VerbTense.future: 'future',
      },
      promptLabels: const <_VerbPerson, String>{
        _VerbPerson.firstSingular: 'I',
        _VerbPerson.secondSingular: 'you',
        _VerbPerson.thirdSingular: 'he/she',
        _VerbPerson.firstPlural: 'we',
        _VerbPerson.secondPlural: 'you all',
        _VerbPerson.thirdPlural: 'they',
      },
      subjectVariants: const <_VerbPerson, List<String>>{
        _VerbPerson.firstSingular: <String>['I'],
        _VerbPerson.secondSingular: <String>['you'],
        _VerbPerson.thirdSingular: <String>['he', 'she'],
        _VerbPerson.firstPlural: <String>['we'],
        _VerbPerson.secondPlural: <String>['you all', 'you'],
        _VerbPerson.thirdPlural: <String>['they'],
      },
    ),
    LearningLanguage.spanish: _VerbLanguageResources(
      profile: BaseLanguageProfile(
        language: LearningLanguage.spanish,
        code: 'es',
        label: 'Spanish',
        locale: 'es-ES',
        textDirection: TextDirection.ltr,
        ttsPreviewText: 'yo hablare',
        preferredSpeechLocaleId: 'es_ES',
        normalizer: _normalizeLatin,
      ),
      tenseLabels: const <_VerbTense, String>{
        _VerbTense.present: 'presente',
        _VerbTense.past: 'pasado',
        _VerbTense.future: 'futuro',
      },
      promptLabels: const <_VerbPerson, String>{
        _VerbPerson.firstSingular: 'yo',
        _VerbPerson.secondSingular: 'tu',
        _VerbPerson.thirdSingular: 'el/ella',
        _VerbPerson.firstPlural: 'nosotros',
        _VerbPerson.secondPlural: 'vosotros',
        _VerbPerson.thirdPlural: 'ellos/ellas',
      },
      subjectVariants: const <_VerbPerson, List<String>>{
        _VerbPerson.firstSingular: <String>['yo'],
        _VerbPerson.secondSingular: <String>['tu'],
        _VerbPerson.thirdSingular: <String>['el', 'ella'],
        _VerbPerson.firstPlural: <String>['nosotros', 'nosotras'],
        _VerbPerson.secondPlural: <String>['vosotros', 'vosotras'],
        _VerbPerson.thirdPlural: <String>['ellos', 'ellas'],
      },
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
        _VerbGymModule(resourcesByLanguage: resourcesByLanguage),
      ],
    ),
  );
}

class _VerbGymModule implements TrainingModule {
  _VerbGymModule({required this.resourcesByLanguage});

  final Map<LearningLanguage, _VerbLanguageResources> resourcesByLanguage;

  static final Map<_VerbTense, ExerciseFamily> _families =
      <_VerbTense, ExerciseFamily>{
        _VerbTense.present: ExerciseFamily(
          moduleId: 'verbs',
          id: 'present',
          label: 'Present',
          shortLabel: 'Present',
          difficultyTier: ExerciseDifficultyTier.easy,
          defaultDuration: const Duration(seconds: 18),
          supportedModes: const <ExerciseMode>[
            ExerciseMode.speak,
            ExerciseMode.chooseFromPrompt,
            ExerciseMode.chooseFromAnswer,
            ExerciseMode.listenAndChoose,
          ],
        ),
        _VerbTense.past: ExerciseFamily(
          moduleId: 'verbs',
          id: 'past',
          label: 'Past',
          shortLabel: 'Past',
          difficultyTier: ExerciseDifficultyTier.hard,
          defaultDuration: const Duration(seconds: 22),
          supportedModes: const <ExerciseMode>[
            ExerciseMode.speak,
            ExerciseMode.chooseFromPrompt,
            ExerciseMode.chooseFromAnswer,
            ExerciseMode.listenAndChoose,
          ],
        ),
        _VerbTense.future: ExerciseFamily(
          moduleId: 'verbs',
          id: 'future',
          label: 'Future',
          shortLabel: 'Future',
          difficultyTier: ExerciseDifficultyTier.hard,
          defaultDuration: const Duration(seconds: 22),
          supportedModes: const <ExerciseMode>[
            ExerciseMode.speak,
            ExerciseMode.chooseFromPrompt,
            ExerciseMode.chooseFromAnswer,
            ExerciseMode.listenAndChoose,
          ],
        ),
      };

  @override
  String get moduleId => 'verbs';

  @override
  String get displayName => 'Verb Gym';

  @override
  bool supportsLanguage(LearningLanguage language) {
    return resourcesByLanguage.containsKey(language);
  }

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) {
    if (!supportsLanguage(language)) {
      return const <ExerciseFamily>[];
    }
    return _families.values.toList(growable: false);
  }

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    final resources = resourcesByLanguage[language];
    if (resources == null) {
      return const <ExerciseCard>[];
    }

    final seeds = switch (language) {
      LearningLanguage.english => _buildEnglishSeeds(resources),
      LearningLanguage.spanish => _buildSpanishSeeds(resources),
      _ => const <_VerbSeed>[],
    };

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
          options: _buildAnswerOptions(seed, seeds),
        ),
        chooseFromAnswer: ChoiceExerciseSpec(
          prompt: seed.canonicalAnswer,
          correctOption: seed.displayText,
          options: _buildPromptOptions(seed, seeds),
        ),
        listenAndChoose: ListeningExerciseSpec(
          speechText: seed.audioText,
          correctOption: seed.displayText,
          options: _buildPromptOptions(seed, seeds),
        ),
      );
    }).toList(growable: false);
  }

  List<String> _buildAnswerOptions(_VerbSeed seed, List<_VerbSeed> allSeeds) {
    return _buildOptions(
      seed: seed,
      allSeeds: allSeeds,
      valueOf: (candidate) => candidate.canonicalAnswer,
    );
  }

  List<String> _buildPromptOptions(_VerbSeed seed, List<_VerbSeed> allSeeds) {
    return _buildOptions(
      seed: seed,
      allSeeds: allSeeds,
      valueOf: (candidate) => candidate.displayText,
    );
  }

  List<String> _buildOptions({
    required _VerbSeed seed,
    required List<_VerbSeed> allSeeds,
    required String Function(_VerbSeed candidate) valueOf,
  }) {
    final options = <String>[valueOf(seed)];

    void addFrom(Iterable<_VerbSeed> candidates) {
      for (final candidate in candidates) {
        if (candidate.id == seed.id || candidate.lemma == seed.lemma) {
          continue;
        }
        final value = valueOf(candidate);
        if (options.contains(value)) {
          continue;
        }
        options.add(value);
        if (options.length == 4) {
          return;
        }
      }
    }

    addFrom(
      allSeeds.where(
        (candidate) =>
            candidate.tense == seed.tense && candidate.person == seed.person,
      ),
    );
    if (options.length < 4) {
      addFrom(allSeeds.where((candidate) => candidate.tense == seed.tense));
    }
    if (options.length < 4) {
      addFrom(allSeeds);
    }

    return options;
  }

  List<_VerbSeed> _buildEnglishSeeds(_VerbLanguageResources resources) {
    return _englishVerbs.expand((spec) {
      return _VerbTense.values.expand((tense) {
        final family = _families[tense]!;
        return _VerbPerson.values.map((person) {
          final canonical = _englishSurface(spec, tense, person);
          final promptLabel =
              '${resources.promptLabels[person]!} / ${spec.infinitive} / ${resources.tenseLabels[tense]!}';
          final acceptedAnswers = _uniqueStrings(<String>[
            canonical,
            for (final subject in resources.subjectVariants[person]!)
              '$subject $canonical',
          ]);
          return _VerbSeed(
            id: ExerciseId(
              moduleId: moduleId,
              familyId: family.id,
              variantId: '${spec.infinitive}::${person.key}',
            ),
            family: family,
            lemma: spec.infinitive,
            tense: tense,
            person: person,
            displayText: promptLabel,
            canonicalAnswer: canonical,
            acceptedAnswers: acceptedAnswers,
            audioText: acceptedAnswers.firstWhere(
              (value) => value.contains(' '),
              orElse: () => canonical,
            ),
            celebrationText: '$promptLabel -> $canonical',
          );
        });
      });
    }).toList(growable: false);
  }

  List<_VerbSeed> _buildSpanishSeeds(_VerbLanguageResources resources) {
    return _spanishVerbs.expand((spec) {
      return _VerbTense.values.expand((tense) {
        final family = _families[tense]!;
        return _VerbPerson.values.map((person) {
          final canonical = _spanishSurface(spec, tense, person);
          final promptLabel =
              '${resources.promptLabels[person]!} / ${spec.infinitive} / ${resources.tenseLabels[tense]!}';
          final acceptedAnswers = _uniqueStrings(<String>[
            canonical,
            for (final subject in resources.subjectVariants[person]!)
              '$subject $canonical',
          ]);
          return _VerbSeed(
            id: ExerciseId(
              moduleId: moduleId,
              familyId: family.id,
              variantId: '${spec.infinitive}::${person.key}',
            ),
            family: family,
            lemma: spec.infinitive,
            tense: tense,
            person: person,
            displayText: promptLabel,
            canonicalAnswer: canonical,
            acceptedAnswers: acceptedAnswers,
            audioText: '${resources.subjectVariants[person]!.first} $canonical',
            celebrationText: '$promptLabel -> $canonical',
          );
        });
      });
    }).toList(growable: false);
  }
}

class _VerbLanguageResources {
  const _VerbLanguageResources({
    required this.profile,
    required this.tenseLabels,
    required this.promptLabels,
    required this.subjectVariants,
  });

  final BaseLanguageProfile profile;
  final Map<_VerbTense, String> tenseLabels;
  final Map<_VerbPerson, String> promptLabels;
  final Map<_VerbPerson, List<String>> subjectVariants;
}

class _VerbSeed {
  const _VerbSeed({
    required this.id,
    required this.family,
    required this.lemma,
    required this.tense,
    required this.person,
    required this.displayText,
    required this.canonicalAnswer,
    required this.acceptedAnswers,
    required this.audioText,
    required this.celebrationText,
  });

  final ExerciseId id;
  final ExerciseFamily family;
  final String lemma;
  final _VerbTense tense;
  final _VerbPerson person;
  final String displayText;
  final String canonicalAnswer;
  final List<String> acceptedAnswers;
  final String audioText;
  final String celebrationText;
}

enum _VerbTense { present, past, future }

enum _VerbPerson {
  firstSingular('1s'),
  secondSingular('2s'),
  thirdSingular('3s'),
  firstPlural('1p'),
  secondPlural('2p'),
  thirdPlural('3p');

  const _VerbPerson(this.key);

  final String key;
}

class _EnglishVerbSpec {
  const _EnglishVerbSpec({
    required this.infinitive,
    this.presentThirdSingular,
    this.past,
    this.presentOverrides = const <_VerbPerson, String>{},
    this.pastOverrides = const <_VerbPerson, String>{},
  });

  final String infinitive;
  final String? presentThirdSingular;
  final String? past;
  final Map<_VerbPerson, String> presentOverrides;
  final Map<_VerbPerson, String> pastOverrides;
}

class _SpanishVerbSpec {
  const _SpanishVerbSpec({
    required this.infinitive,
    this.presentStemChange,
    this.presentYo,
    this.presentOverrides = const <_VerbPerson, String>{},
    this.pastOverrides = const <_VerbPerson, String>{},
    this.futureStem,
  });

  final String infinitive;
  final _SpanishStemChange? presentStemChange;
  final String? presentYo;
  final Map<_VerbPerson, String> presentOverrides;
  final Map<_VerbPerson, String> pastOverrides;
  final String? futureStem;
}

enum _SpanishStemChange { eToIe, oToUe, eToI }

String _englishSurface(
  _EnglishVerbSpec spec,
  _VerbTense tense,
  _VerbPerson person,
) {
  switch (tense) {
    case _VerbTense.present:
      final override = spec.presentOverrides[person];
      if (override != null) {
        return override;
      }
      if (person == _VerbPerson.thirdSingular) {
        return spec.presentThirdSingular ?? _englishThirdSingular(spec.infinitive);
      }
      return spec.infinitive;
    case _VerbTense.past:
      final override = spec.pastOverrides[person];
      if (override != null) {
        return override;
      }
      return spec.past ?? _englishRegularPast(spec.infinitive);
    case _VerbTense.future:
      return 'will ${spec.infinitive}';
  }
}

String _englishThirdSingular(String infinitive) {
  if (infinitive.endsWith('y') && infinitive.length > 1) {
    final beforeY = infinitive[infinitive.length - 2];
    if (!_isVowel(beforeY)) {
      return '${infinitive.substring(0, infinitive.length - 1)}ies';
    }
  }
  if (infinitive.endsWith('o') ||
      infinitive.endsWith('s') ||
      infinitive.endsWith('sh') ||
      infinitive.endsWith('ch') ||
      infinitive.endsWith('x') ||
      infinitive.endsWith('z')) {
    return '${infinitive}es';
  }
  return '${infinitive}s';
}

String _englishRegularPast(String infinitive) {
  if (infinitive.endsWith('e')) {
    return '${infinitive}d';
  }
  if (infinitive.endsWith('y') && infinitive.length > 1) {
    final beforeY = infinitive[infinitive.length - 2];
    if (!_isVowel(beforeY)) {
      return '${infinitive.substring(0, infinitive.length - 1)}ied';
    }
  }
  return '${infinitive}ed';
}

String _spanishSurface(
  _SpanishVerbSpec spec,
  _VerbTense tense,
  _VerbPerson person,
) {
  switch (tense) {
    case _VerbTense.present:
      final override = spec.presentOverrides[person];
      if (override != null) {
        return override;
      }
      if (person == _VerbPerson.firstSingular && spec.presentYo != null) {
        return spec.presentYo!;
      }
      return _spanishRegularPresent(spec, person);
    case _VerbTense.past:
      final override = spec.pastOverrides[person];
      if (override != null) {
        return override;
      }
      return _spanishRegularPast(spec.infinitive, person);
    case _VerbTense.future:
      return _spanishFuture(spec, person);
  }
}

String _spanishRegularPresent(_SpanishVerbSpec spec, _VerbPerson person) {
  final infinitive = spec.infinitive;
  final ending = infinitive.substring(infinitive.length - 2);
  final baseStem = infinitive.substring(0, infinitive.length - 2);
  final usesStemChange =
      person != _VerbPerson.firstPlural && person != _VerbPerson.secondPlural;
  final stem = usesStemChange
      ? _applySpanishStemChange(baseStem, spec.presentStemChange)
      : baseStem;

  switch (ending) {
    case 'ar':
      return '$stem${switch (person) {
        _VerbPerson.firstSingular => 'o',
        _VerbPerson.secondSingular => 'as',
        _VerbPerson.thirdSingular => 'a',
        _VerbPerson.firstPlural => 'amos',
        _VerbPerson.secondPlural => 'ais',
        _VerbPerson.thirdPlural => 'an',
      }}';
    case 'er':
      return '$stem${switch (person) {
        _VerbPerson.firstSingular => 'o',
        _VerbPerson.secondSingular => 'es',
        _VerbPerson.thirdSingular => 'e',
        _VerbPerson.firstPlural => 'emos',
        _VerbPerson.secondPlural => 'eis',
        _VerbPerson.thirdPlural => 'en',
      }}';
    case 'ir':
      return '$stem${switch (person) {
        _VerbPerson.firstSingular => 'o',
        _VerbPerson.secondSingular => 'es',
        _VerbPerson.thirdSingular => 'e',
        _VerbPerson.firstPlural => 'imos',
        _VerbPerson.secondPlural => 'is',
        _VerbPerson.thirdPlural => 'en',
      }}';
    default:
      return infinitive;
  }
}

String _spanishRegularPast(String infinitive, _VerbPerson person) {
  final ending = infinitive.substring(infinitive.length - 2);
  var stem = infinitive.substring(0, infinitive.length - 2);

  if (person == _VerbPerson.firstSingular) {
    if (infinitive.endsWith('car')) {
      stem = '${stem.substring(0, stem.length - 1)}qu';
    } else if (infinitive.endsWith('gar')) {
      stem = '${stem.substring(0, stem.length - 1)}gu';
    } else if (infinitive.endsWith('zar')) {
      stem = '${stem.substring(0, stem.length - 1)}c';
    }
  }

  final arEndings = <_VerbPerson, String>{
    _VerbPerson.firstSingular: 'e',
    _VerbPerson.secondSingular: 'aste',
    _VerbPerson.thirdSingular: 'o',
    _VerbPerson.firstPlural: 'amos',
    _VerbPerson.secondPlural: 'asteis',
    _VerbPerson.thirdPlural: 'aron',
  };
  final erIrEndings = <_VerbPerson, String>{
    _VerbPerson.firstSingular: 'i',
    _VerbPerson.secondSingular: 'iste',
    _VerbPerson.thirdSingular: 'io',
    _VerbPerson.firstPlural: 'imos',
    _VerbPerson.secondPlural: 'isteis',
    _VerbPerson.thirdPlural: 'ieron',
  };

  final endings = ending == 'ar' ? arEndings : erIrEndings;
  return '$stem${endings[person]!}';
}

String _spanishFuture(_SpanishVerbSpec spec, _VerbPerson person) {
  final stem = spec.futureStem ?? spec.infinitive;
  final ending = switch (person) {
    _VerbPerson.firstSingular => 'e',
    _VerbPerson.secondSingular => 'as',
    _VerbPerson.thirdSingular => 'a',
    _VerbPerson.firstPlural => 'emos',
    _VerbPerson.secondPlural => 'eis',
    _VerbPerson.thirdPlural => 'an',
  };
  return '$stem$ending';
}

String _applySpanishStemChange(String stem, _SpanishStemChange? change) {
  if (change == null) {
    return stem;
  }
  switch (change) {
    case _SpanishStemChange.eToIe:
      return _replaceLast(stem, 'e', 'ie');
    case _SpanishStemChange.oToUe:
      return _replaceLast(stem, 'o', 'ue');
    case _SpanishStemChange.eToI:
      return _replaceLast(stem, 'e', 'i');
  }
}

String _replaceLast(String source, String needle, String replacement) {
  final index = source.lastIndexOf(needle);
  if (index < 0) {
    return source;
  }
  return '${source.substring(0, index)}$replacement${source.substring(index + needle.length)}';
}

bool _isVowel(String char) {
  return const <String>{'a', 'e', 'i', 'o', 'u'}.contains(char.toLowerCase());
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
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const List<_EnglishVerbSpec> _englishVerbs = <_EnglishVerbSpec>[
  _EnglishVerbSpec(
    infinitive: 'be',
    presentOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'am',
      _VerbPerson.secondSingular: 'are',
      _VerbPerson.thirdSingular: 'is',
      _VerbPerson.firstPlural: 'are',
      _VerbPerson.secondPlural: 'are',
      _VerbPerson.thirdPlural: 'are',
    },
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'was',
      _VerbPerson.secondSingular: 'were',
      _VerbPerson.thirdSingular: 'was',
      _VerbPerson.firstPlural: 'were',
      _VerbPerson.secondPlural: 'were',
      _VerbPerson.thirdPlural: 'were',
    },
  ),
  _EnglishVerbSpec(infinitive: 'have', presentThirdSingular: 'has', past: 'had'),
  _EnglishVerbSpec(infinitive: 'do', presentThirdSingular: 'does', past: 'did'),
  _EnglishVerbSpec(infinitive: 'say', presentThirdSingular: 'says', past: 'said'),
  _EnglishVerbSpec(infinitive: 'go', presentThirdSingular: 'goes', past: 'went'),
  _EnglishVerbSpec(infinitive: 'get', past: 'got'),
  _EnglishVerbSpec(infinitive: 'make', past: 'made'),
  _EnglishVerbSpec(infinitive: 'know', past: 'knew'),
  _EnglishVerbSpec(infinitive: 'think', past: 'thought'),
  _EnglishVerbSpec(infinitive: 'take', past: 'took'),
  _EnglishVerbSpec(infinitive: 'see', past: 'saw'),
  _EnglishVerbSpec(infinitive: 'come', past: 'came'),
  _EnglishVerbSpec(infinitive: 'want'),
  _EnglishVerbSpec(infinitive: 'look'),
  _EnglishVerbSpec(infinitive: 'use'),
  _EnglishVerbSpec(infinitive: 'find', past: 'found'),
  _EnglishVerbSpec(infinitive: 'give', past: 'gave'),
  _EnglishVerbSpec(infinitive: 'tell', past: 'told'),
  _EnglishVerbSpec(infinitive: 'work'),
  _EnglishVerbSpec(infinitive: 'call'),
  _EnglishVerbSpec(infinitive: 'try'),
  _EnglishVerbSpec(infinitive: 'ask'),
  _EnglishVerbSpec(infinitive: 'need'),
  _EnglishVerbSpec(infinitive: 'feel', past: 'felt'),
  _EnglishVerbSpec(infinitive: 'become', past: 'became'),
  _EnglishVerbSpec(infinitive: 'leave', past: 'left'),
  _EnglishVerbSpec(infinitive: 'put', past: 'put'),
  _EnglishVerbSpec(infinitive: 'mean', past: 'meant'),
  _EnglishVerbSpec(infinitive: 'keep', past: 'kept'),
  _EnglishVerbSpec(infinitive: 'let', past: 'let'),
  _EnglishVerbSpec(infinitive: 'begin', past: 'began'),
  _EnglishVerbSpec(infinitive: 'seem'),
  _EnglishVerbSpec(infinitive: 'help'),
  _EnglishVerbSpec(infinitive: 'talk'),
  _EnglishVerbSpec(infinitive: 'turn'),
  _EnglishVerbSpec(infinitive: 'start'),
  _EnglishVerbSpec(infinitive: 'show', past: 'showed'),
  _EnglishVerbSpec(infinitive: 'hear', past: 'heard'),
  _EnglishVerbSpec(infinitive: 'play'),
  _EnglishVerbSpec(infinitive: 'run', past: 'ran'),
  _EnglishVerbSpec(infinitive: 'move'),
  _EnglishVerbSpec(infinitive: 'live'),
  _EnglishVerbSpec(infinitive: 'believe'),
  _EnglishVerbSpec(infinitive: 'bring', past: 'brought'),
  _EnglishVerbSpec(infinitive: 'happen'),
  _EnglishVerbSpec(infinitive: 'write', past: 'wrote'),
  _EnglishVerbSpec(infinitive: 'provide'),
  _EnglishVerbSpec(infinitive: 'sit', past: 'sat'),
  _EnglishVerbSpec(infinitive: 'stand', past: 'stood'),
  _EnglishVerbSpec(infinitive: 'lose', past: 'lost'),
];

const List<_SpanishVerbSpec> _spanishVerbs = <_SpanishVerbSpec>[
  _SpanishVerbSpec(
    infinitive: 'ser',
    presentOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'soy',
      _VerbPerson.secondSingular: 'eres',
      _VerbPerson.thirdSingular: 'es',
      _VerbPerson.firstPlural: 'somos',
      _VerbPerson.secondPlural: 'sois',
      _VerbPerson.thirdPlural: 'son',
    },
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'fui',
      _VerbPerson.secondSingular: 'fuiste',
      _VerbPerson.thirdSingular: 'fue',
      _VerbPerson.firstPlural: 'fuimos',
      _VerbPerson.secondPlural: 'fuisteis',
      _VerbPerson.thirdPlural: 'fueron',
    },
  ),
  _SpanishVerbSpec(
    infinitive: 'estar',
    presentYo: 'estoy',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'estuve',
      _VerbPerson.secondSingular: 'estuviste',
      _VerbPerson.thirdSingular: 'estuvo',
      _VerbPerson.firstPlural: 'estuvimos',
      _VerbPerson.secondPlural: 'estuvisteis',
      _VerbPerson.thirdPlural: 'estuvieron',
    },
  ),
  _SpanishVerbSpec(
    infinitive: 'tener',
    presentStemChange: _SpanishStemChange.eToIe,
    presentYo: 'tengo',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'tuve',
      _VerbPerson.secondSingular: 'tuviste',
      _VerbPerson.thirdSingular: 'tuvo',
      _VerbPerson.firstPlural: 'tuvimos',
      _VerbPerson.secondPlural: 'tuvisteis',
      _VerbPerson.thirdPlural: 'tuvieron',
    },
    futureStem: 'tendr',
  ),
  _SpanishVerbSpec(
    infinitive: 'hacer',
    presentYo: 'hago',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'hice',
      _VerbPerson.secondSingular: 'hiciste',
      _VerbPerson.thirdSingular: 'hizo',
      _VerbPerson.firstPlural: 'hicimos',
      _VerbPerson.secondPlural: 'hicisteis',
      _VerbPerson.thirdPlural: 'hicieron',
    },
    futureStem: 'har',
  ),
  _SpanishVerbSpec(
    infinitive: 'decir',
    presentStemChange: _SpanishStemChange.eToI,
    presentYo: 'digo',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'dije',
      _VerbPerson.secondSingular: 'dijiste',
      _VerbPerson.thirdSingular: 'dijo',
      _VerbPerson.firstPlural: 'dijimos',
      _VerbPerson.secondPlural: 'dijisteis',
      _VerbPerson.thirdPlural: 'dijeron',
    },
    futureStem: 'dir',
  ),
  _SpanishVerbSpec(
    infinitive: 'ir',
    presentOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'voy',
      _VerbPerson.secondSingular: 'vas',
      _VerbPerson.thirdSingular: 'va',
      _VerbPerson.firstPlural: 'vamos',
      _VerbPerson.secondPlural: 'vais',
      _VerbPerson.thirdPlural: 'van',
    },
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'fui',
      _VerbPerson.secondSingular: 'fuiste',
      _VerbPerson.thirdSingular: 'fue',
      _VerbPerson.firstPlural: 'fuimos',
      _VerbPerson.secondPlural: 'fuisteis',
      _VerbPerson.thirdPlural: 'fueron',
    },
  ),
  _SpanishVerbSpec(infinitive: 'ver', presentYo: 'veo', pastOverrides: <_VerbPerson, String>{
    _VerbPerson.firstSingular: 'vi',
    _VerbPerson.secondSingular: 'viste',
    _VerbPerson.thirdSingular: 'vio',
    _VerbPerson.firstPlural: 'vimos',
    _VerbPerson.secondPlural: 'visteis',
    _VerbPerson.thirdPlural: 'vieron',
  }),
  _SpanishVerbSpec(
    infinitive: 'dar',
    presentOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'doy',
      _VerbPerson.secondSingular: 'das',
      _VerbPerson.thirdSingular: 'da',
      _VerbPerson.firstPlural: 'damos',
      _VerbPerson.secondPlural: 'dais',
      _VerbPerson.thirdPlural: 'dan',
    },
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'di',
      _VerbPerson.secondSingular: 'diste',
      _VerbPerson.thirdSingular: 'dio',
      _VerbPerson.firstPlural: 'dimos',
      _VerbPerson.secondPlural: 'disteis',
      _VerbPerson.thirdPlural: 'dieron',
    },
  ),
  _SpanishVerbSpec(
    infinitive: 'saber',
    presentOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'se',
    },
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'supe',
      _VerbPerson.secondSingular: 'supiste',
      _VerbPerson.thirdSingular: 'supo',
      _VerbPerson.firstPlural: 'supimos',
      _VerbPerson.secondPlural: 'supisteis',
      _VerbPerson.thirdPlural: 'supieron',
    },
    futureStem: 'sabr',
  ),
  _SpanishVerbSpec(
    infinitive: 'querer',
    presentStemChange: _SpanishStemChange.eToIe,
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'quise',
      _VerbPerson.secondSingular: 'quisiste',
      _VerbPerson.thirdSingular: 'quiso',
      _VerbPerson.firstPlural: 'quisimos',
      _VerbPerson.secondPlural: 'quisisteis',
      _VerbPerson.thirdPlural: 'quisieron',
    },
    futureStem: 'querr',
  ),
  _SpanishVerbSpec(infinitive: 'llegar'),
  _SpanishVerbSpec(infinitive: 'pasar'),
  _SpanishVerbSpec(infinitive: 'deber'),
  _SpanishVerbSpec(
    infinitive: 'poner',
    presentYo: 'pongo',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'puse',
      _VerbPerson.secondSingular: 'pusiste',
      _VerbPerson.thirdSingular: 'puso',
      _VerbPerson.firstPlural: 'pusimos',
      _VerbPerson.secondPlural: 'pusisteis',
      _VerbPerson.thirdPlural: 'pusieron',
    },
    futureStem: 'pondr',
  ),
  _SpanishVerbSpec(infinitive: 'parecer', presentYo: 'parezco'),
  _SpanishVerbSpec(infinitive: 'quedar'),
  _SpanishVerbSpec(
    infinitive: 'creer',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'crei',
      _VerbPerson.secondSingular: 'creiste',
      _VerbPerson.thirdSingular: 'creyo',
      _VerbPerson.firstPlural: 'creimos',
      _VerbPerson.secondPlural: 'creisteis',
      _VerbPerson.thirdPlural: 'creyeron',
    },
  ),
  _SpanishVerbSpec(infinitive: 'hablar'),
  _SpanishVerbSpec(infinitive: 'llevar'),
  _SpanishVerbSpec(infinitive: 'dejar'),
  _SpanishVerbSpec(
    infinitive: 'seguir',
    presentStemChange: _SpanishStemChange.eToI,
    presentYo: 'sigo',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.thirdSingular: 'siguio',
      _VerbPerson.thirdPlural: 'siguieron',
    },
  ),
  _SpanishVerbSpec(infinitive: 'encontrar', presentStemChange: _SpanishStemChange.oToUe),
  _SpanishVerbSpec(infinitive: 'llamar'),
  _SpanishVerbSpec(
    infinitive: 'venir',
    presentStemChange: _SpanishStemChange.eToIe,
    presentYo: 'vengo',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'vine',
      _VerbPerson.secondSingular: 'viniste',
      _VerbPerson.thirdSingular: 'vino',
      _VerbPerson.firstPlural: 'vinimos',
      _VerbPerson.secondPlural: 'vinisteis',
      _VerbPerson.thirdPlural: 'vinieron',
    },
    futureStem: 'vendr',
  ),
  _SpanishVerbSpec(infinitive: 'pensar', presentStemChange: _SpanishStemChange.eToIe),
  _SpanishVerbSpec(
    infinitive: 'salir',
    presentYo: 'salgo',
    futureStem: 'saldr',
  ),
  _SpanishVerbSpec(infinitive: 'volver', presentStemChange: _SpanishStemChange.oToUe),
  _SpanishVerbSpec(infinitive: 'tomar'),
  _SpanishVerbSpec(infinitive: 'conocer', presentYo: 'conozco'),
  _SpanishVerbSpec(infinitive: 'vivir'),
  _SpanishVerbSpec(
    infinitive: 'sentir',
    presentStemChange: _SpanishStemChange.eToIe,
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.thirdSingular: 'sintio',
      _VerbPerson.thirdPlural: 'sintieron',
    },
  ),
  _SpanishVerbSpec(infinitive: 'tratar'),
  _SpanishVerbSpec(infinitive: 'mirar'),
  _SpanishVerbSpec(infinitive: 'contar', presentStemChange: _SpanishStemChange.oToUe),
  _SpanishVerbSpec(infinitive: 'empezar', presentStemChange: _SpanishStemChange.eToIe),
  _SpanishVerbSpec(infinitive: 'esperar'),
  _SpanishVerbSpec(infinitive: 'buscar'),
  _SpanishVerbSpec(infinitive: 'existir'),
  _SpanishVerbSpec(infinitive: 'entrar'),
  _SpanishVerbSpec(infinitive: 'trabajar'),
  _SpanishVerbSpec(infinitive: 'escribir'),
  _SpanishVerbSpec(infinitive: 'perder', presentStemChange: _SpanishStemChange.eToIe),
  _SpanishVerbSpec(
    infinitive: 'producir',
    presentYo: 'produzco',
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.firstSingular: 'produje',
      _VerbPerson.secondSingular: 'produjiste',
      _VerbPerson.thirdSingular: 'produjo',
      _VerbPerson.firstPlural: 'produjimos',
      _VerbPerson.secondPlural: 'produjisteis',
      _VerbPerson.thirdPlural: 'produjeron',
    },
  ),
  _SpanishVerbSpec(infinitive: 'ocurrir'),
  _SpanishVerbSpec(infinitive: 'entender', presentStemChange: _SpanishStemChange.eToIe),
  _SpanishVerbSpec(
    infinitive: 'pedir',
    presentStemChange: _SpanishStemChange.eToI,
    pastOverrides: <_VerbPerson, String>{
      _VerbPerson.thirdSingular: 'pidio',
      _VerbPerson.thirdPlural: 'pidieron',
    },
  ),
  _SpanishVerbSpec(infinitive: 'recibir'),
  _SpanishVerbSpec(infinitive: 'recordar', presentStemChange: _SpanishStemChange.oToUe),
  _SpanishVerbSpec(infinitive: 'terminar'),
  _SpanishVerbSpec(infinitive: 'abrir'),
];
