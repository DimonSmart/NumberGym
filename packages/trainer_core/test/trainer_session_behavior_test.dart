import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

import 'helpers/training_fakes.dart';

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

const _moduleId = 'test';

final _testFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'test_family',
  label: 'Test',
  shortLabel: 'Test',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.chooseFromPrompt],
);

class _TestModule implements TrainingModule {
  @override
  String get moduleId => _moduleId;

  @override
  String get displayName => 'Test';

  @override
  bool supportsLanguage(LearningLanguage language) =>
      language == LearningLanguage.english;

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) =>
      [_testFamily];

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    return List.generate(10, (i) {
      final id = ExerciseId(
        moduleId: _moduleId,
        familyId: 'test_family',
        variantId: '$i',
      );
      return ExerciseCard(
        id: id,
        family: _testFamily,
        language: language,
        displayText: '$i',
        promptText: '$i',
        acceptedAnswers: ['option_$i'],
        celebrationText: 'learned $i',
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: '$i',
          correctOption: 'option_$i',
          options: ['option_$i', 'other_1', 'other_2', 'other_3'],
        ),
      );
    });
  }
}

final _singleFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'single_family',
  label: 'Single',
  shortLabel: 'Single',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.chooseFromPrompt],
);

class _SingleCardModule implements TrainingModule {
  @override
  String get moduleId => _moduleId;

  @override
  String get displayName => 'Single';

  @override
  bool supportsLanguage(LearningLanguage language) =>
      language == LearningLanguage.english;

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) =>
      [_singleFamily];

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    const id = ExerciseId(
      moduleId: _moduleId,
      familyId: 'single_family',
      variantId: '0',
    );
    return [
      ExerciseCard(
        id: id,
        family: _singleFamily,
        language: language,
        displayText: 'one',
        promptText: 'one',
        acceptedAnswers: const ['one'],
        celebrationText: 'learned one',
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: 'one',
          correctOption: 'one',
          options: const ['one', 'two', 'three', 'four'],
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _identityNormalizer(String text) => text.toLowerCase();

class _SimpleTokenizer implements MatcherTokenizer {
  @override
  List<MatchingToken> tokenize(String text) => [
        MatchingToken(display: text, normalized: text.toLowerCase()),
      ];
}

TrainingAppDefinition _buildAppDefinition({
  TrainingModule? module,
}) {
  const profile = BaseLanguageProfile(
    language: LearningLanguage.english,
    code: 'en',
    label: 'English',
    locale: 'en-US',
    textDirection: TextDirection.ltr,
    ttsPreviewText: 'test',
    preferredSpeechLocaleId: null,
    normalizer: _identityNormalizer,
  );
  return TrainingAppDefinition(
    config: const AppConfig(
      appId: 'test',
      title: 'Test',
      homeTitle: 'Test',
      repositoryUrl: 'https://example.com',
      privacyPolicyUrl: 'https://example.com/privacy',
      aboutTitle: 'About',
      aboutBody: 'Test',
      settingsBoxName: 'test_settings',
      progressBoxName: 'test_progress',
      heroAssetPath: 'assets/hero.png',
      mascotAssetPath: 'assets/mascot.png',
    ),
    supportedLanguages: [LearningLanguage.english],
    profileOf: (_) => profile,
    tokenizerOf: (_) => _SimpleTokenizer(),
    catalog: ExerciseCatalog(modules: [module ?? _TestModule()]),
  );
}

TrainerController _buildController({
  TrainingModule? module,
  InMemoryProgressRepository? progressRepository,
  VoidCallback? onAutoStop,
}) {
  return TrainerController(
    appDefinition: _buildAppDefinition(module: module),
    settingsRepository: FakeSettingsRepository(),
    progressRepository: progressRepository ?? InMemoryProgressRepository(),
    services: buildFakeTrainingServices(),
    onAutoStop: onAutoStop,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test(
    'startTraining attaches runtime and stopTraining clears state',
    () async {
      final controller = _buildController();

      await controller.initialize();
      await controller.startTraining();

      expect(controller.currentTask, isNotNull);

      await controller.stopTraining();

      expect(controller.currentTask, isNull);
      expect(controller.state.feedback, isNull);
      controller.dispose();
    },
  );

  test(
    'session reaches card limit after completing sessionTargetCards',
    () async {
      final controller = _buildController();

      await controller.initialize();
      await controller.startTraining();

      expect(controller.currentTask, isNotNull);

      // Complete cards with user interaction to prevent auto-stop
      final target = controller.sessionTargetCards;
      for (var i = 0; i < target; i++) {
        await controller.completeCurrentTaskWithOutcome(
          TrainingOutcome.skipped,
          simulatedUserInteraction: true,
        );
      }

      expect(controller.state.sessionStats, isNotNull);
      expect(controller.state.sessionStats!.cardsCompleted, target);
      expect(controller.currentTask, isNull);
      controller.dispose();
    },
  );

  test(
    'continueSession clears sessionStats and resumes training',
    () async {
      final controller = _buildController();

      await controller.initialize();
      await controller.startTraining();

      final target = controller.sessionTargetCards;
      for (var i = 0; i < target; i++) {
        await controller.completeCurrentTaskWithOutcome(
          TrainingOutcome.skipped,
          simulatedUserInteraction: true,
        );
      }
      expect(controller.state.sessionStats, isNotNull);

      await controller.continueSession();

      expect(controller.state.sessionStats, isNull);
      expect(controller.currentTask, isNotNull);
      controller.dispose();
    },
  );

  test(
    'celebration fires when card transitions to learned',
    () async {
      // Seed card with 19 correct attempts so one more correct triggers learning
      const cardId = ExerciseId(
        moduleId: _moduleId,
        familyId: 'single_family',
        variantId: '0',
      );
      final progressRepository = InMemoryProgressRepository();
      await progressRepository.save(
        cardId.storageKey,
        const CardProgress(
          learned: false,
          clusters: <CardCluster>[
            CardCluster(
              lastAnswerAt: 1000, // 1970 — far enough back for a new cluster
              correctCount: 19,
              wrongCount: 0,
              skippedCount: 0,
            ),
          ],
          learnedAt: 0,
          firstAttemptAt: 1000,
          consecutiveCorrect: 19,
        ),
        language: LearningLanguage.english,
      );

      final controller = _buildController(
        module: _SingleCardModule(),
        progressRepository: progressRepository,
      );

      await controller.initialize();
      await controller.startTraining();

      expect(controller.currentTask, isNotNull);

      // One correct answer → total 20, accuracy 1.0 → learned!
      await controller.completeCurrentTaskWithOutcome(TrainingOutcome.correct);

      expect(controller.celebration, isNotNull);
      expect(controller.celebration!.categoryLabel, isNotEmpty);
      controller.dispose();
    },
  );
}
