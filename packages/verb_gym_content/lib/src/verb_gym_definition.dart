import 'package:flutter/widgets.dart';
import 'package:trainer_core/trainer_core.dart';

import 'default_verb_concept_authoring_data.dart';
import 'verb_authoring_loader.dart';
import 'verb_authoring_models.dart';

const String _verbGymModuleId = 'verb_gym';

const List<ExerciseMode> _verbExerciseModes = <ExerciseMode>[
  ExerciseMode.speak,
  ExerciseMode.chooseFromPrompt,
  ExerciseMode.chooseFromAnswer,
  ExerciseMode.listenAndChoose,
];

final VerbRuntimeCatalog _defaultRuntimeCatalog = const VerbAuthoringLoader()
    .loadRuntimeCatalogFromJsonStrings(defaultVerbConceptAuthoringJsonSources);

TrainingAppDefinition buildVerbGymAppDefinition({
  required AppConfig config,
  VerbRuntimeCatalog? runtimeCatalog,
}) {
  final resourcesByLanguage = <LearningLanguage, _VerbLanguageResources>{
    LearningLanguage.english: _VerbLanguageResources(
      profile: BaseLanguageProfile(
        language: LearningLanguage.english,
        code: 'en',
        label: 'English',
        locale: 'en-US',
        textDirection: TextDirection.ltr,
        ttsPreviewText: 'I am hungry',
        preferredSpeechLocaleId: 'en_US',
        normalizer: _normalizeLatin,
      ),
    ),
    LearningLanguage.spanish: _VerbLanguageResources(
      profile: BaseLanguageProfile(
        language: LearningLanguage.spanish,
        code: 'es',
        label: 'Spanish',
        locale: 'es-ES',
        textDirection: TextDirection.ltr,
        ttsPreviewText: 'yo tengo hambre',
        preferredSpeechLocaleId: 'es_ES',
        normalizer: _normalizeLatin,
      ),
    ),
  };

  return TrainingAppDefinition(
    config: config,
    supportedLanguages: resourcesByLanguage.keys.toList(growable: false),
    profileOf: (language) => resourcesByLanguage[language]!.profile,
    tokenizerOf: (language) => GenericMatcherTokenizer(
      resourcesByLanguage[language]!.profile.normalizer,
    ),
    catalog: ExerciseCatalog(
      modules: <TrainingModule>[
        _VerbGymModule(
          runtimeCatalog: runtimeCatalog ?? _defaultRuntimeCatalog,
          resourcesByLanguage: resourcesByLanguage,
          defaultBaseLanguage: config.defaultBaseLanguage,
        ),
      ],
    ),
  );
}

class _VerbGymModule implements ContextualTrainingModule {
  _VerbGymModule({
    required this.runtimeCatalog,
    required Map<LearningLanguage, _VerbLanguageResources> resourcesByLanguage,
    required this.defaultBaseLanguage,
  }) : resourcesByLanguage =
           Map<LearningLanguage, _VerbLanguageResources>.unmodifiable(
             resourcesByLanguage,
           );

  final VerbRuntimeCatalog runtimeCatalog;
  final Map<LearningLanguage, _VerbLanguageResources> resourcesByLanguage;
  final LearningLanguage defaultBaseLanguage;

  @override
  String get moduleId => _verbGymModuleId;

  @override
  String get displayName => 'Verb Gym';

  @override
  bool supportsLanguage(LearningLanguage language) {
    return resourcesByLanguage.containsKey(language);
  }

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) {
    return buildFamiliesForContext(
      TrainingLanguageContext(
        baseLanguage: defaultBaseLanguage,
        learningLanguage: language,
      ),
    );
  }

  @override
  List<ExerciseFamily> buildFamiliesForContext(
    TrainingLanguageContext context,
  ) {
    final learningResources = resourcesByLanguage[context.learningLanguage];
    final baseResources = resourcesByLanguage[context.baseLanguage];
    if (learningResources == null || baseResources == null) {
      return const <ExerciseFamily>[];
    }

    final availableTenseIds = _availableTenseIds(
      learningResources: learningResources,
      baseResources: baseResources,
    );
    return <ExerciseFamily>[
      for (final tenseId in _tenseOrder)
        if (availableTenseIds.contains(tenseId)) _tenseFamilies[tenseId]!,
    ];
  }

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    return buildCardsForContext(
      TrainingLanguageContext(
        baseLanguage: defaultBaseLanguage,
        learningLanguage: language,
      ),
    );
  }

  @override
  List<ExerciseCard> buildCardsForContext(TrainingLanguageContext context) {
    final learningResources = resourcesByLanguage[context.learningLanguage];
    final baseResources = resourcesByLanguage[context.baseLanguage];
    if (learningResources == null || baseResources == null) {
      return const <ExerciseCard>[];
    }

    final seeds = _buildCardSeeds(
      learningResources: learningResources,
      baseResources: baseResources,
    );
    return seeds
        .map((seed) {
          return ExerciseCard(
            id: seed.id,
            progressId: seed.id,
            family: seed.family,
            language: context.learningLanguage,
            displayText: seed.promptText,
            promptText: seed.answerText,
            acceptedAnswers: _acceptedAnswerVariants(seed.answerText),
            celebrationText: '${seed.promptText} -> ${seed.answerText}',
            chooseFromPrompt: ChoiceExerciseSpec(
              prompt: seed.promptText,
              correctOption: seed.answerText,
              options: _buildAnswerOptions(seed, seeds),
            ),
            chooseFromAnswer: ChoiceExerciseSpec(
              prompt: seed.answerText,
              correctOption: seed.promptText,
              options: _buildPromptOptions(seed, seeds),
            ),
            listenAndChoose: ListeningExerciseSpec(
              speechText: seed.answerText,
              correctOption: seed.promptText,
              options: _buildPromptOptions(seed, seeds),
            ),
          );
        })
        .toList(growable: false);
  }

  Set<String> _availableTenseIds({
    required _VerbLanguageResources learningResources,
    required _VerbLanguageResources baseResources,
  }) {
    final tenseIds = <String>{};
    for (final concept in runtimeCatalog.concepts) {
      for (final tenseEntry in concept.examplesByTenseAndRole.entries) {
        final hasLanguageExample = tenseEntry.value.values
            .expand((examples) => examples)
            .any(
              (example) => _hasTextForCard(
                example,
                learningResources: learningResources,
                baseResources: baseResources,
              ),
            );
        if (hasLanguageExample) {
          tenseIds.add(tenseEntry.key);
        }
      }
    }
    return tenseIds;
  }

  List<_VerbCardSeed> _buildCardSeeds({
    required _VerbLanguageResources learningResources,
    required _VerbLanguageResources baseResources,
  }) {
    final seeds = <_VerbCardSeed>[];
    for (final concept in runtimeCatalog.concepts) {
      for (final tenseEntry in concept.examplesByTenseAndRole.entries) {
        final family = _tenseFamilies[tenseEntry.key];
        if (family == null) {
          continue;
        }

        for (final roleEntry in tenseEntry.value.entries) {
          final examples = roleEntry.value;
          for (var index = 0; index < examples.length; index += 1) {
            final example = examples[index];
            if (!_hasTextForCard(
              example,
              learningResources: learningResources,
              baseResources: baseResources,
            )) {
              continue;
            }

            final suffix = examples.length == 1 ? '' : '::$index';
            seeds.add(
              _VerbCardSeed(
                id: ExerciseId(
                  moduleId: moduleId,
                  familyId: family.id,
                  variantId: '${concept.id.value}::${example.role}$suffix',
                ),
                family: family,
                conceptId: concept.id,
                tenseId: tenseEntry.key,
                role: example.role,
                promptText: _promptText(example, concept, baseResources),
                answerText: example.text[learningResources.profile.code]!,
              ),
            );
          }
        }
      }
    }
    return seeds;
  }

  bool _hasTextForCard(
    VerbRuntimeExample example, {
    required _VerbLanguageResources learningResources,
    required _VerbLanguageResources baseResources,
  }) {
    return example.text.containsKey(learningResources.profile.code) &&
        example.text.containsKey(baseResources.profile.code);
  }

  String _promptText(
    VerbRuntimeExample example,
    VerbRuntimeConcept concept,
    _VerbLanguageResources resources,
  ) {
    return example.text[resources.profile.code] ??
        concept.concept.meaning[resources.profile.code]?.short ??
        concept.id.value;
  }

  List<String> _buildAnswerOptions(
    _VerbCardSeed seed,
    List<_VerbCardSeed> allSeeds,
  ) {
    return _buildOptions(
      seed: seed,
      allSeeds: allSeeds,
      valueOf: (candidate) => candidate.answerText,
    );
  }

  List<String> _buildPromptOptions(
    _VerbCardSeed seed,
    List<_VerbCardSeed> allSeeds,
  ) {
    return _buildOptions(
      seed: seed,
      allSeeds: allSeeds,
      valueOf: (candidate) => candidate.promptText,
    );
  }

  List<String> _buildOptions({
    required _VerbCardSeed seed,
    required List<_VerbCardSeed> allSeeds,
    required String Function(_VerbCardSeed candidate) valueOf,
  }) {
    final options = <String>[valueOf(seed)];

    void addFrom(Iterable<_VerbCardSeed> candidates) {
      for (final candidate in candidates) {
        if (candidate.id == seed.id) {
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
            candidate.tenseId == seed.tenseId && candidate.role == seed.role,
      ),
    );
    if (options.length < 4) {
      addFrom(allSeeds.where((candidate) => candidate.tenseId == seed.tenseId));
    }
    if (options.length < 4) {
      addFrom(allSeeds);
    }

    return options;
  }
}

class _VerbLanguageResources {
  const _VerbLanguageResources({required this.profile});

  final BaseLanguageProfile profile;
}

class _VerbCardSeed {
  const _VerbCardSeed({
    required this.id,
    required this.family,
    required this.conceptId,
    required this.tenseId,
    required this.role,
    required this.promptText,
    required this.answerText,
  });

  final ExerciseId id;
  final ExerciseFamily family;
  final VerbConceptId conceptId;
  final String tenseId;
  final String role;
  final String promptText;
  final String answerText;
}

class _VerbTenseFamilyDefinition {
  const _VerbTenseFamilyDefinition({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.difficultyTier,
    required this.defaultDuration,
  });

  final String id;
  final String label;
  final String shortLabel;
  final ExerciseDifficultyTier difficultyTier;
  final Duration defaultDuration;

  ExerciseFamily toFamily() {
    return ExerciseFamily(
      moduleId: _verbGymModuleId,
      id: id,
      label: label,
      shortLabel: shortLabel,
      difficultyTier: difficultyTier,
      defaultDuration: defaultDuration,
      supportedModes: _verbExerciseModes,
    );
  }
}

const List<String> _tenseOrder = <String>[
  VerbTenseIds.presentIndicative,
  VerbTenseIds.presentPerfect,
  VerbTenseIds.preterite,
  VerbTenseIds.imperfectIndicative,
  VerbTenseIds.futureSimple,
  VerbTenseIds.conditionalSimple,
  VerbTenseIds.presentSubjunctive,
  VerbTenseIds.imperfectSubjunctive,
];

final Map<String, ExerciseFamily> _tenseFamilies =
    <String, _VerbTenseFamilyDefinition>{
      VerbTenseIds.presentIndicative: const _VerbTenseFamilyDefinition(
        id: VerbTenseIds.presentIndicative,
        label: 'Present indicative',
        shortLabel: 'Present',
        difficultyTier: ExerciseDifficultyTier.easy,
        defaultDuration: Duration(seconds: 18),
      ),
      VerbTenseIds.presentPerfect: const _VerbTenseFamilyDefinition(
        id: VerbTenseIds.presentPerfect,
        label: 'Present perfect',
        shortLabel: 'Present perfect',
        difficultyTier: ExerciseDifficultyTier.medium,
        defaultDuration: Duration(seconds: 20),
      ),
      VerbTenseIds.preterite: const _VerbTenseFamilyDefinition(
        id: VerbTenseIds.preterite,
        label: 'Preterite',
        shortLabel: 'Preterite',
        difficultyTier: ExerciseDifficultyTier.medium,
        defaultDuration: Duration(seconds: 20),
      ),
      VerbTenseIds.imperfectIndicative: const _VerbTenseFamilyDefinition(
        id: VerbTenseIds.imperfectIndicative,
        label: 'Imperfect indicative',
        shortLabel: 'Imperfect',
        difficultyTier: ExerciseDifficultyTier.medium,
        defaultDuration: Duration(seconds: 20),
      ),
      VerbTenseIds.futureSimple: const _VerbTenseFamilyDefinition(
        id: VerbTenseIds.futureSimple,
        label: 'Future simple',
        shortLabel: 'Future',
        difficultyTier: ExerciseDifficultyTier.hard,
        defaultDuration: Duration(seconds: 22),
      ),
      VerbTenseIds.conditionalSimple: const _VerbTenseFamilyDefinition(
        id: VerbTenseIds.conditionalSimple,
        label: 'Conditional simple',
        shortLabel: 'Conditional',
        difficultyTier: ExerciseDifficultyTier.hard,
        defaultDuration: Duration(seconds: 22),
      ),
      VerbTenseIds.presentSubjunctive: const _VerbTenseFamilyDefinition(
        id: VerbTenseIds.presentSubjunctive,
        label: 'Present subjunctive',
        shortLabel: 'Subjunctive',
        difficultyTier: ExerciseDifficultyTier.hard,
        defaultDuration: Duration(seconds: 24),
      ),
      VerbTenseIds.imperfectSubjunctive: const _VerbTenseFamilyDefinition(
        id: VerbTenseIds.imperfectSubjunctive,
        label: 'Imperfect subjunctive',
        shortLabel: 'Imperfect subjunctive',
        difficultyTier: ExerciseDifficultyTier.hard,
        defaultDuration: Duration(seconds: 24),
      ),
    }.map(
      (id, definition) =>
          MapEntry<String, ExerciseFamily>(id, definition.toFamily()),
    );

List<String> _acceptedAnswerVariants(String answerText) {
  return _uniqueStrings(<String>[
    answerText,
    answerText.replaceFirst(RegExp(r'[.?!]+$'), ''),
  ]);
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
