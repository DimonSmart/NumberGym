import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym_content/number_gym_content.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  final definition = buildNumberGymAppDefinition(config: _config);

  test('definition exposes all legacy family ids and languages', () {
    final snapshot = definition.catalog.build(LearningLanguage.english);

    expect(definition.supportedLanguages, equals(LearningLanguage.values));
    expect(
      snapshot.familiesByKey.keys.toList(),
      containsAll(<String>[
        'number_gym/digits',
        'number_gym/base',
        'number_gym/hundreds',
        'number_gym/thousands',
        'number_gym/timeExact',
        'number_gym/timeQuarter',
        'number_gym/timeHalf',
        'number_gym/timeRandom',
        'number_gym/phone33x3',
        'number_gym/phone3222',
        'number_gym/phone2322',
      ]),
    );
  });

  test('english exact-time cards accept numeric o clock aliases', () {
    final card = _findCard(
      definition: definition,
      language: LearningLanguage.english,
      familyId: 'timeExact',
      variantId: '12:00',
    );
    final matcher =
        AnswerMatcher(
          normalizer: definition.profileOf(LearningLanguage.english).normalizer,
          tokenizer: definition.tokenizerOf(LearningLanguage.english),
        )..reset(
          prompt: card.promptText,
          answers: card.acceptedAnswers,
          promptAliases: card.matcherConfig.promptAliases,
        );

    final result = matcher.applyRecognition('12 o clock');

    expect(card.matcherConfig.promptAliases, contains('12 o clock'));
    expect(result.matchedSegmentIndices, equals(const <int>[0]));
    expect(matcher.isComplete, isTrue);
  });

  test('random-time card keeps stable progress id and changes display', () {
    final base = _findCard(
      definition: definition,
      language: LearningLanguage.english,
      familyId: 'timeRandom',
      variantId: 'random',
    );

    final first = base.resolveDynamic();
    final second = base.resolveDynamic();

    expect(first.id, equals(base.id));
    expect(first.progressId, equals(base.progressId));
    expect(second.id, equals(base.id));
    expect(second.progressId, equals(base.progressId));
    expect(second.displayText, isNot(equals(first.displayText)));
  });

  test('phone families stay speak-only and use grouped spoken hints', () {
    final base = _findFirstCardInFamily(
      definition: definition,
      language: LearningLanguage.english,
      familyId: 'phone3222',
    );
    final resolved = base.resolveDynamic();
    final hint = resolved.acceptedAnswers.firstWhere(
      (candidate) =>
          candidate.trim().isNotEmpty &&
          candidate.trim().toLowerCase() != resolved.promptText.toLowerCase(),
    );

    expect(
      base.family.supportedModes,
      equals(const <ExerciseMode>[ExerciseMode.speak]),
    );
    expect(base.family.masteryAccuracy, 0.8);
    expect(resolved.chooseFromPrompt, isNull);
    expect(resolved.chooseFromAnswer, isNull);
    expect(resolved.listenAndChoose, isNull);
    expect(hint.contains(_bullet), isTrue);
    expect(RegExp(r'^[+\d\s]+$').hasMatch(hint), isFalse);
  });

  test(
    'number cards expose pronunciation review but time and phone cards do not',
    () {
      final numberCard = _findCard(
        definition: definition,
        language: LearningLanguage.english,
        familyId: 'digits',
        variantId: '5',
      );
      final timeCard = _findCard(
        definition: definition,
        language: LearningLanguage.english,
        familyId: 'timeExact',
        variantId: '12:00',
      );
      final phoneCard = _findFirstCardInFamily(
        definition: definition,
        language: LearningLanguage.english,
        familyId: 'phone33x3',
      );

      expect(numberCard.reviewPronunciation, isNotNull);
      expect(timeCard.reviewPronunciation, isNull);
      expect(phoneCard.reviewPronunciation, isNull);
    },
  );

  test('23:45 mentions midnight wording in every supported language', () {
    for (final language in definition.supportedLanguages) {
      final midnight = _findCard(
        definition: definition,
        language: language,
        familyId: 'timeExact',
        variantId: '00:00',
      );
      final quarterToMidnight = _findCard(
        definition: definition,
        language: language,
        familyId: 'timeQuarter',
        variantId: '23:45',
      );

      expect(
        quarterToMidnight.chooseFromPrompt!.correctOption.contains(
          midnight.chooseFromPrompt!.correctOption,
        ),
        isTrue,
        reason:
            '$language should mention midnight for 23:45, got ${quarterToMidnight.chooseFromPrompt!.correctOption}',
      );
    }
  });
}

ExerciseCard _findCard({
  required TrainingAppDefinition definition,
  required LearningLanguage language,
  required String familyId,
  required String variantId,
}) {
  return definition.catalog
      .build(language)
      .cards
      .firstWhere(
        (card) =>
            card.id.familyId == familyId && card.id.variantId == variantId,
      );
}

ExerciseCard _findFirstCardInFamily({
  required TrainingAppDefinition definition,
  required LearningLanguage language,
  required String familyId,
}) {
  return definition.catalog
      .build(language)
      .cards
      .firstWhere((card) => card.id.familyId == familyId);
}

const AppConfig _config = AppConfig(
  appId: 'number_gym_test',
  title: 'Number Gym',
  homeTitle: 'Number Gym',
  repositoryUrl: 'https://example.com/repo',
  privacyPolicyUrl: 'https://example.com/privacy',
  aboutTitle: 'About Number Gym',
  aboutBody: 'About body',
  settingsBoxName: 'settings_test',
  progressBoxName: 'progress_v2_test',
  heroAssetPath: 'assets/images/branding/wordmark.png',
  mascotAssetPath: 'assets/images/app_icon_transparent.png',
);

const _bullet = '•';
