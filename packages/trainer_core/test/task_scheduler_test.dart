import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

import 'helpers/training_fakes.dart';

const _moduleId = 'test';

// Module with chooseFromPrompt only (for "no cards" test)
final _choiceOnlyFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'choice_family',
  label: 'Choice',
  shortLabel: 'Choice',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.chooseFromPrompt],
);

class _ChoiceOnlyModule implements TrainingModule {
  @override
  String get moduleId => _moduleId;

  @override
  String get displayName => 'Choice';

  @override
  bool supportsLanguage(LearningLanguage language) => true;

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) =>
      [_choiceOnlyFamily];

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    return List.generate(5, (i) {
      final id = ExerciseId(
        moduleId: _moduleId,
        familyId: 'choice_family',
        variantId: '$i',
      );
      return ExerciseCard(
        id: id,
        family: _choiceOnlyFamily,
        language: language,
        displayText: '$i',
        promptText: '$i',
        acceptedAnswers: ['option_$i'],
        celebrationText: '$i',
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: '$i',
          correctOption: 'option_$i',
          options: ['option_$i', 'other_1', 'other_2', 'other_3'],
        ),
      );
    });
  }
}

// Module that supports all modes (for internet/speech availability tests)
final _allModesFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'all_modes_family',
  label: 'All Modes',
  shortLabel: 'All',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [
    ExerciseMode.speak,
    ExerciseMode.chooseFromPrompt,
    ExerciseMode.reviewPronunciation,
  ],
);

class _AllModesModule implements TrainingModule {
  @override
  String get moduleId => _moduleId;

  @override
  String get displayName => 'All Modes';

  @override
  bool supportsLanguage(LearningLanguage language) => true;

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) =>
      [_allModesFamily];

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    return List.generate(5, (i) {
      final id = ExerciseId(
        moduleId: _moduleId,
        familyId: 'all_modes_family',
        variantId: '$i',
      );
      return ExerciseCard(
        id: id,
        family: _allModesFamily,
        language: language,
        displayText: '$i',
        promptText: '$i',
        acceptedAnswers: ['option_$i'],
        celebrationText: '$i',
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: '$i',
          correctOption: 'option_$i',
          options: ['option_$i', 'other_1', 'other_2', 'other_3'],
        ),
      );
    });
  }
}

BaseLanguageProfile _buildProfile() {
  return const BaseLanguageProfile(
    language: LearningLanguage.english,
    code: 'en',
    label: 'English',
    locale: 'en-US',
    textDirection: TextDirection.ltr,
    ttsPreviewText: 'test',
    preferredSpeechLocaleId: null,
    normalizer: _identityNormalizer,
  );
}

String _identityNormalizer(String text) => text.toLowerCase();

Future<ProgressManager> _buildProgressManager({
  required TrainingModule module,
  LearningLanguage language = LearningLanguage.english,
  Map<String, CardProgress> seeded = const {},
}) async {
  final repo = InMemoryProgressRepository();
  for (final entry in seeded.entries) {
    await repo.save(entry.key, entry.value, language: language);
  }
  final manager = ProgressManager(
    progressRepository: repo,
    catalog: ExerciseCatalog(modules: [module]),
  );
  await manager.loadProgress(language);
  return manager;
}

void main() {
  test(
    'forced mode with incompatible cards returns paused with filter message',
    () async {
      // _ChoiceOnlyModule only supports chooseFromPrompt, not speak
      final progressManager = await _buildProgressManager(
        module: _ChoiceOnlyModule(),
      );
      final scheduler = TaskScheduler(
        availabilityRegistry: TaskAvailabilityRegistry(providers: []),
        internetChecker: () async => true,
      );

      final result = await scheduler.scheduleNext(
        progressManager: progressManager,
        language: LearningLanguage.english,
        profile: _buildProfile(),
        premiumPronunciationEnabled: false,
        forcedMode: ExerciseMode.speak,
      );

      expect(result, isA<TaskSchedulePaused>());
      final paused = result as TaskSchedulePaused;
      expect(paused.errorMessage, contains('No cards available'));
    },
  );

  test(
    'no internet + forced reviewPronunciation returns paused with internet message',
    () async {
      final progressManager = await _buildProgressManager(
        module: _AllModesModule(),
      );
      final scheduler = TaskScheduler(
        availabilityRegistry: TaskAvailabilityRegistry(
          providers: [ReviewPronunciationAvailabilityProvider()],
        ),
        internetChecker: () async => false,
      );

      final result = await scheduler.scheduleNext(
        progressManager: progressManager,
        language: LearningLanguage.english,
        profile: _buildProfile(),
        premiumPronunciationEnabled: true,
        forcedMode: ExerciseMode.reviewPronunciation,
      );

      expect(result, isA<TaskSchedulePaused>());
      final paused = result as TaskSchedulePaused;
      expect(paused.errorMessage.toLowerCase(), contains('internet'));
    },
  );

  test('all cards learned returns TaskScheduleFinished', () async {
    // Seed all 5 cards as learned
    final module = _ChoiceOnlyModule();
    final cards = module.buildCards(LearningLanguage.english);
    final seeded = <String, CardProgress>{
      for (final card in cards)
        card.id.storageKey: const CardProgress(
          learned: true,
          clusters: <CardCluster>[
            CardCluster(
              lastAnswerAt: 1000,
              correctCount: 20,
              wrongCount: 0,
              skippedCount: 0,
            ),
          ],
          learnedAt: 1000,
          firstAttemptAt: 900,
          consecutiveCorrect: 20,
        ),
    };

    final progressManager = await _buildProgressManager(
      module: _ChoiceOnlyModule(),
      seeded: seeded,
    );
    final scheduler = TaskScheduler(
      availabilityRegistry: TaskAvailabilityRegistry(providers: []),
      internetChecker: () async => true,
    );

    final result = await scheduler.scheduleNext(
      progressManager: progressManager,
      language: LearningLanguage.english,
      profile: _buildProfile(),
      premiumPronunciationEnabled: false,
    );

    expect(result, isA<TaskScheduleFinished>());
  });

  test(
    'speech not ready + forced speak returns paused with Speech message',
    () async {
      final progressManager = await _buildProgressManager(
        module: _AllModesModule(),
      );
      final scheduler = TaskScheduler(
        availabilityRegistry: TaskAvailabilityRegistry(
          providers: [
            SpeechTaskAvailabilityProvider(FakeSpeechService(ready: false)),
          ],
        ),
        internetChecker: () async => true,
      );

      final result = await scheduler.scheduleNext(
        progressManager: progressManager,
        language: LearningLanguage.english,
        profile: _buildProfile(),
        premiumPronunciationEnabled: false,
        forcedMode: ExerciseMode.speak,
      );

      expect(result, isA<TaskSchedulePaused>());
      final paused = result as TaskSchedulePaused;
      expect(paused.errorMessage.toLowerCase(), contains('speech'));
    },
  );
}
