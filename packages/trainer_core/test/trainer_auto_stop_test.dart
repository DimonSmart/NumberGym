import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

import 'helpers/training_fakes.dart';

// ---------------------------------------------------------------------------
// Minimal catalog that only uses chooseFromPrompt - no TTS or speech needed
// ---------------------------------------------------------------------------

const _moduleId = 'test';

final _testFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'test_family',
  label: 'Test',
  shortLabel: 'Test',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 10),
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
        celebrationText: '$i',
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: '$i',
          correctOption: 'option_$i',
          options: ['option_$i', 'option_${i + 10}', 'option_${i + 20}', 'option_${i + 30}'],
        ),
      );
    });
  }
}

String _identityNormalizer(String text) => text.toLowerCase();

TrainingAppDefinition _buildTestAppDefinition() {
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
    catalog: ExerciseCatalog(modules: [_TestModule()]),
  );
}

class _SimpleTokenizer implements MatcherTokenizer {
  @override
  List<MatchingToken> tokenize(String text) => [
        MatchingToken(display: text, normalized: text.toLowerCase()),
      ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test(
    'auto-stop fires after 3 consecutive skipped outcomes without user interaction',
    () async {
      var autoStopCalled = 0;

      final controller = TrainerController(
        appDefinition: _buildTestAppDefinition(),
        settingsRepository: FakeSettingsRepository(),
        progressRepository: InMemoryProgressRepository(),
        services: buildFakeTrainingServices(),
        onAutoStop: () => autoStopCalled++,
      );

      await controller.initialize();
      await controller.startTraining();

      expect(controller.currentTask, isNotNull, reason: 'task after start');

      await controller.completeCurrentTaskWithOutcome(TrainingOutcome.skipped);
      await controller.completeCurrentTaskWithOutcome(TrainingOutcome.skipped);
      await controller.completeCurrentTaskWithOutcome(TrainingOutcome.skipped);

      expect(autoStopCalled, 1);
      expect(controller.currentTask, isNull);
      expect(controller.sessionCardsCompleted, 3);

      controller.dispose();
    },
  );

  test(
    'auto-stop does not fire when user interaction resets the streak',
    () async {
      var autoStopCalled = 0;

      final controller = TrainerController(
        appDefinition: _buildTestAppDefinition(),
        settingsRepository: FakeSettingsRepository(),
        progressRepository: InMemoryProgressRepository(),
        services: buildFakeTrainingServices(),
        onAutoStop: () => autoStopCalled++,
      );

      await controller.initialize();
      await controller.startTraining();

      // Build up streak to 2
      await controller.completeCurrentTaskWithOutcome(TrainingOutcome.skipped);
      await controller.completeCurrentTaskWithOutcome(TrainingOutcome.skipped);

      // Reset streak via a simulated user interaction
      await controller.completeCurrentTaskWithOutcome(
        TrainingOutcome.skipped,
        simulatedUserInteraction: true,
      );

      // Two more skips - streak is 2, below threshold of 3
      await controller.completeCurrentTaskWithOutcome(TrainingOutcome.skipped);
      await controller.completeCurrentTaskWithOutcome(TrainingOutcome.skipped);

      expect(autoStopCalled, 0);
      expect(controller.currentTask, isNotNull);

      controller.dispose();
    },
  );
}
