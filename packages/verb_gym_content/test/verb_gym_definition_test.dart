import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:verb_gym_content/verb_gym_content.dart';

void main() {
  final definition = buildVerbGymAppDefinition(config: _config);

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
      variantId: 'be_hungry::I',
    );

    expect(card.id.moduleId, 'verb_gym');
    expect(card.displayText, 'I am hungry.');
    expect(card.promptText, 'Yo tengo hambre.');
    expect(
      card.acceptedAnswers,
      containsAll(<String>['Yo tengo hambre.', 'Yo tengo hambre']),
    );
    expect(card.celebrationText, 'I am hungry. -> Yo tengo hambre.');
    expect(card.concept, isNotNull);
    expect(card.concept!.id, 'be_hungry');
    expect(card.concept!.learningLabel, 'tener hambre');
    expect(card.concept!.baseLabel, 'to be hungry');
  });

  test('English cards reverse the prompt and answer languages', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.spanish,
      language: LearningLanguage.english,
      familyId: VerbTenseIds.presentIndicative,
      variantId: 'be_hungry::I',
    );

    expect(card.displayText, 'Yo tengo hambre.');
    expect(card.promptText, 'I am hungry.');
  });

  test('same base and learning language is allowed', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.spanish,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.presentIndicative,
      variantId: 'be_hungry::I',
    );

    expect(card.displayText, 'Yo tengo hambre.');
    expect(card.promptText, 'Yo tengo hambre.');
  });

  test('Spanish cards include simple past examples', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.preterite,
      variantId: 'be_hungry::I',
    );

    expect(card.displayText, 'I was hungry yesterday.');
    expect(card.promptText, 'Yo tuve hambre ayer.');
    expect(
      card.acceptedAnswers,
      containsAll(<String>['Yo tuve hambre ayer.', 'Yo tuve hambre ayer']),
    );
  });

  test('Spanish cards include future simple examples', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.futureSimple,
      variantId: 'go_to_place::I',
    );

    expect(card.displayText, 'I will go to the park tomorrow.');
    expect(card.promptText, 'Yo iré al parque mañana.');
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
    expect(variantIds, contains('be_hungry::I'));
    expect(variantIds, contains('be_hungry::You'));
    expect(variantIds, contains('be_hungry::YouPluralFormal'));
  });

  test('answer options prefer the same tense and role', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.presentIndicative,
      variantId: 'be_hungry::I',
    );

    final options = card.chooseFromPrompt!.options;
    expect(options, hasLength(4));
    for (final option in options) {
      expect(option.startsWith('Yo '), isTrue);
    }
  });

  test('matcher accepts generated sentence with and without final period', () {
    final card = _findCard(
      definition: definition,
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
      familyId: VerbTenseIds.presentIndicative,
      variantId: 'be_hungry::I',
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

    expect(matcher.isAcceptedAnswer('Yo tengo hambre.'), isTrue);
    expect(matcher.isAcceptedAnswer('Yo tengo hambre'), isTrue);
  });
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
