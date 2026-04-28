import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:verb_gym_content/verb_gym_content.dart';

void main() {
  late TrainingAppDefinition definition;

  setUpAll(() async {
    final runtimeCatalog = await VerbAuthoringAssetLoader(
      bundle: _FileAssetBundle(_authoringAssetDirectory()),
    ).loadRuntimeCatalog();
    definition = buildVerbGymAppDefinition(
      config: _config,
      runtimeCatalog: runtimeCatalog,
    );
  });

  test('uses compact concept grid statistics display', () {
    expect(
      definition.statisticsDisplay.conceptDisplayMode,
      StatisticsConceptDisplayMode.compactGrid,
    );
    expect(definition.statisticsDisplay.compactGridMaxColumns, 5);
  });

  test('families are built from available verb tenses', () {
    final catalog = definition.catalog.build(
      LearningLanguage.spanish,
      baseLanguage: LearningLanguage.english,
    );

    expect(catalog.familiesByKey.keys, <String>[
      'verb_gym/${VerbTenseIds.presentIndicative}',
      'verb_gym/${VerbTenseIds.preterite}',
      'verb_gym/${VerbTenseIds.futureSimple}',
    ]);
    expect(
      catalog
          .familiesByKey['verb_gym/${VerbTenseIds.presentIndicative}']!
          .label,
      'Present indicative',
    );
    expect(
      catalog.familiesByKey['verb_gym/${VerbTenseIds.presentIndicative}']!
          .labelFor(LearningLanguage.spanish),
      'Presente de indicativo',
    );
    expect(
      catalog.familiesByKey['verb_gym/${VerbTenseIds.presentIndicative}']!
          .labelFor(LearningLanguage.english),
      'Present indicative',
    );
    expect(
      catalog.familiesByKey['verb_gym/${VerbTenseIds.preterite}']!.label,
      'Simple past',
    );
    expect(
      catalog.familiesByKey['verb_gym/${VerbTenseIds.futureSimple}']!.label,
      'Future simple',
    );
  });

  test('Spanish cards use tense as family and role as variant', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.presentIndicative,
      variantId: 'eat_meal::I',
    );

    expect(card.id.moduleId, 'verb_gym');
    expect(card.displayText, 'Yo como una comida.');
    expect(card.promptText, 'Yo como una comida.');
    expect(
      card.acceptedAnswers,
      containsAll(<String>['Yo como una comida.', 'Yo como una comida']),
    );
    expect(card.celebrationText, 'I eat a meal. -> Yo como una comida.');
    expect(card.concept, isNotNull);
    expect(card.concept!.id, 'eat_meal');
    expect(card.concept!.learningLabel, 'comer una comida');
    expect(card.concept!.baseLabel, 'to eat a meal');
    expect(card.chooseFromPrompt!.prompt, 'I eat a meal.');
    expect(card.chooseFromPrompt!.correctOption, 'Yo como una comida.');
    expect(card.chooseFromAnswer!.prompt, 'Yo como una comida.');
    expect(card.chooseFromAnswer!.correctOption, 'I eat a meal.');
    expect(card.listenAndChoose!.speechText, 'Yo como una comida.');
    expect(card.listenAndChoose!.correctOption, 'I eat a meal.');
  });

  test('English cards reverse the prompt and answer languages', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.spanish,
      language: LearningLanguage.english,
      familyId: VerbTenseIds.presentIndicative,
      variantId: 'eat_meal::I',
    );

    expect(card.displayText, 'I eat a meal.');
    expect(card.promptText, 'I eat a meal.');
  });

  test('same base and learning language is allowed', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.spanish,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.presentIndicative,
      variantId: 'eat_meal::I',
    );

    expect(card.displayText, 'Yo como una comida.');
    expect(card.promptText, 'Yo como una comida.');
  });

  test('Spanish cards include simple past examples', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.preterite,
      variantId: 'eat_meal::I',
    );

    expect(card.displayText, 'Yo comí una comida ayer.');
    expect(card.promptText, 'Yo comí una comida ayer.');
    expect(
      card.acceptedAnswers,
      containsAll(<String>[
        'Yo comí una comida ayer.',
        'Yo comí una comida ayer',
      ]),
    );
  });

  test('Spanish cards include future simple examples', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.futureSimple,
      variantId: 'travel_to_city::I',
    );

    expect(card.displayText, 'Yo viajaré a la ciudad mañana.');
    expect(card.promptText, 'Yo viajaré a la ciudad mañana.');
  });

  test('roles remain card variants instead of separate families', () {
    final catalog = definition.catalog.build(
      LearningLanguage.spanish,
      baseLanguage: LearningLanguage.english,
    );
    final familyIds = catalog.cards.map((card) => card.id.familyId).toSet();
    final variantIds = catalog.cards.map((card) => card.id.variantId).toSet();

    expect(familyIds, <String>{
      VerbTenseIds.presentIndicative,
      VerbTenseIds.preterite,
      VerbTenseIds.futureSimple,
    });
    expect(variantIds, contains('eat_meal::I'));
    expect(variantIds, contains('eat_meal::You'));
    expect(variantIds, contains('eat_meal::YouPluralFormal'));
  });

  test('answer options include the same concept in other tenses', () {
    final catalog = definition.catalog.build(
      LearningLanguage.spanish,
      baseLanguage: LearningLanguage.english,
    );
    final card = catalog.cards.firstWhere(
      (card) =>
          card.id.familyId == VerbTenseIds.presentIndicative &&
          card.id.variantId == 'eat_meal::I',
    );

    final options = card.chooseFromPrompt!.options;
    final sameConceptOtherTenseOptions = catalog.cards
        .where(
          (candidate) =>
              candidate.concept!.id == card.concept!.id &&
              candidate.id.familyId != card.id.familyId,
        )
        .map((candidate) => candidate.promptText)
        .where(options.contains)
        .toSet();
    final otherConceptOptions = catalog.cards
        .where((candidate) => candidate.concept!.id != card.concept!.id)
        .map((candidate) => candidate.promptText)
        .where(options.contains)
        .toSet();

    expect(options, hasLength(4));
    expect(options, contains(card.chooseFromPrompt!.correctOption));
    expect(sameConceptOtherTenseOptions, hasLength(greaterThanOrEqualTo(2)));
    expect(otherConceptOptions, hasLength(1));
  });

  test('matcher accepts generated sentence with and without final period', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.presentIndicative,
      variantId: 'eat_meal::I',
    );
    final matcher =
        AnswerMatcher(
          normalizer: definition.profileOf(LearningLanguage.spanish).normalizer,
          tokenizer: definition.tokenizerOf(LearningLanguage.spanish),
        )..reset(
          prompt: card.promptText,
          answers: card.acceptedAnswers,
          promptAliases: card.matcherConfig.promptAliases,
        );

    expect(matcher.isAcceptedAnswer('Yo como una comida.'), isTrue);
    expect(matcher.isAcceptedAnswer('Yo como una comida'), isTrue);
  });

  test('matcher accepts Spanish speech without accent marks or tilde', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.futureSimple,
      variantId: 'travel_to_city::I',
    );
    final matcher =
        AnswerMatcher(
          normalizer: definition.profileOf(LearningLanguage.spanish).normalizer,
          tokenizer: definition.tokenizerOf(LearningLanguage.spanish),
        )..reset(
          prompt: card.promptText,
          answers: card.acceptedAnswers,
          promptAliases: card.matcherConfig.promptAliases,
        );

    final result = matcher.applyRecognition('Yo viajare a la ciudad manana');

    expect(result.acceptedAnswer, isTrue);
    expect(matcher.isComplete, isTrue);
  });

  test('matcher compares decomposed Spanish diacritics as plain letters', () {
    final matcher =
        AnswerMatcher(
          normalizer: definition.profileOf(LearningLanguage.spanish).normalizer,
          tokenizer: definition.tokenizerOf(LearningLanguage.spanish),
        )..reset(
          prompt: 'Yo viajare\u0301 a la ciudad man\u0303ana',
          answers: const <String>[],
          promptAliases: const <String>[],
        );

    final result = matcher.applyRecognition(
      'please yo viajare a la ciudad manana thanks',
    );

    expect(result.acceptedAnswer, isFalse);
    expect(result.matchedSegmentIndices, equals(const <int>[0, 1, 2, 3, 4, 5]));
    expect(matcher.isComplete, isTrue);
  });
}

Directory _authoringAssetDirectory() {
  var directory = Directory.current;
  while (true) {
    final authoringDirectory = directory.uri
        .resolve('packages/verb_gym_content/assets/authoring/')
        .toFilePath();
    if (Directory(authoringDirectory).existsSync()) {
      return Directory(authoringDirectory);
    }

    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'Could not find workspace root from ${Directory.current}',
      );
    }
    directory = parent;
  }
}

class _FileAssetBundle extends CachingAssetBundle {
  _FileAssetBundle(this.directory);

  final Directory directory;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError('String assets only');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final prefix = '$defaultVerbAuthoringAssetRoot/';
    if (!key.startsWith(prefix)) {
      throw ArgumentError.value(key, 'key', 'Unexpected asset key');
    }
    final fileName = key.substring(prefix.length);
    return File.fromUri(directory.uri.resolve(fileName)).readAsString();
  }
}

ExerciseCard _findCard({
  required TrainingAppDefinition definition,
  required LearningLanguage baseLanguage,
  required LearningLanguage language,
  required String familyId,
  required String variantId,
}) {
  return definition.catalog
      .build(language, baseLanguage: baseLanguage)
      .cards
      .firstWhere(
        (card) =>
            card.id.familyId == familyId && card.id.variantId == variantId,
      );
}

const AppConfig _config = AppConfig(
  appId: 'verb_gym_test',
  title: 'Verb Gym',
  homeTitle: 'Verb Gym',
  repositoryUrl: 'https://example.com/repo',
  privacyPolicyUrl: 'https://example.com/privacy',
  aboutTitle: 'About',
  aboutBody: 'About body',
  settingsBoxName: 'verb_gym_settings_test',
  progressBoxName: 'verb_gym_progress_test',
  heroAssetPath: 'assets/images/branding/wordmark.png',
  mascotAssetPath: 'assets/images/app_icon.png',
);
