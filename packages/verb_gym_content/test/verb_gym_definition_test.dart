import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:verb_gym_content/verb_gym_content.dart';

void main() {
  final definition = buildVerbGymAppDefinition(config: _config);

  test('English future cards accept multi-word answers', () {
    final card = _findCard(
      definition: definition,
      language: LearningLanguage.english,
      familyId: 'future',
      variantId: 'go::1s',
    );
    final matcher = AnswerMatcher(
      normalizer: definition.profileOf(LearningLanguage.english).normalizer,
      tokenizer: definition.tokenizerOf(LearningLanguage.english),
    )..reset(
        prompt: card.promptText,
        answers: card.acceptedAnswers,
        promptAliases: card.matcherConfig.promptAliases,
      );

    expect(card.promptText, 'will go');
    expect(matcher.isAcceptedAnswer('will go'), isTrue);
    expect(matcher.isAcceptedAnswer('I will go'), isTrue);
  });

  test('Spanish cards accept forms with and without pronoun', () {
    final card = _findCard(
      definition: definition,
      language: LearningLanguage.spanish,
      familyId: 'present',
      variantId: 'hablar::1s',
    );
    final matcher = AnswerMatcher(
      normalizer: definition.profileOf(LearningLanguage.spanish).normalizer,
      tokenizer: definition.tokenizerOf(LearningLanguage.spanish),
    )..reset(
        prompt: card.promptText,
        answers: card.acceptedAnswers,
        promptAliases: card.matcherConfig.promptAliases,
      );

    expect(card.promptText, 'hablo');
    expect(matcher.isAcceptedAnswer('hablo'), isTrue);
    expect(matcher.isAcceptedAnswer('yo hablo'), isTrue);
  });

  test('Irregular overrides win over generated forms', () {
    final englishPast = _findCard(
      definition: definition,
      language: LearningLanguage.english,
      familyId: 'past',
      variantId: 'go::1s',
    );
    final spanishFuture = _findCard(
      definition: definition,
      language: LearningLanguage.spanish,
      familyId: 'future',
      variantId: 'tener::1s',
    );

    expect(englishPast.promptText, 'went');
    expect(englishPast.promptText, isNot('goed'));
    expect(spanishFuture.promptText, 'tendre');
    expect(spanishFuture.promptText, isNot('tenere'));
  });

  test('Prompt-side distractors keep tense and person aligned', () {
    final card = _findCard(
      definition: definition,
      language: LearningLanguage.english,
      familyId: 'future',
      variantId: 'go::1s',
    );
    final options = card.chooseFromAnswer!.options;

    expect(options, hasLength(4));
    for (final option in options) {
      expect(option.startsWith('I / '), isTrue);
      expect(option.endsWith(' / future'), isTrue);
    }
  });
}

ExerciseCard _findCard({
  required TrainingAppDefinition definition,
  required LearningLanguage language,
  required String familyId,
  required String variantId,
}) {
  return definition.catalog.build(language).cards.firstWhere(
    (card) => card.id.familyId == familyId && card.id.variantId == variantId,
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
  heroAssetPath: 'assets/images/intro.png',
  mascotAssetPath: 'assets/images/app_icon.png',
);
