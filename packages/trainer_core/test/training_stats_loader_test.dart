import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

import 'helpers/training_fakes.dart';

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
  List<ExerciseFamily> buildFamilies(LearningLanguage language) => [
    _testFamily,
  ];

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    return List.generate(5, (i) {
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
          options: ['option_$i', 'other_1', 'other_2', 'other_3'],
        ),
      );
    });
  }
}

void main() {
  test(
    'load returns normalized progress, daily stats, and streak snapshot',
    () async {
      final now = DateTime(2026, 2, 10, 14, 15);
      const language = LearningLanguage.english;

      // Seed progress for card at index 0 (storageKey = 'test/test_family/0')
      const seededId = ExerciseId(
        moduleId: _moduleId,
        familyId: 'test_family',
        variantId: '0',
      );
      final progressRepository = InMemoryProgressRepository();
      await progressRepository.save(
        seededId.storageKey,
        CardProgress(
          learned: true,
          clusters: <CardCluster>[
            CardCluster(
              lastAnswerAt: now.millisecondsSinceEpoch,
              correctCount: 5,
              wrongCount: 1,
              skippedCount: 0,
            ),
          ],
          learnedAt: now.millisecondsSinceEpoch,
          firstAttemptAt: now.millisecondsSinceEpoch,
          consecutiveCorrect: 4,
        ),
        language: language,
      );

      final settingsRepository = FakeSettingsRepository(
        language: language,
        dailySessionStatsByLanguage: {
          language: DailySessionStats(
            dayKey: '2026-02-10',
            sessionsCompleted: 2,
            cardsCompleted: 18,
            durationSeconds: 540,
          ),
        },
        streakByLanguage: {
          language: StudyStreak(
            sessionsByDay: const <String, int>{
              '2026-02-08': 1,
              '2026-02-09': 1,
              '2026-02-10': 2,
            },
          ),
        },
      );
      final loader = TrainingStatsLoader(
        progressRepository: progressRepository,
        settingsRepository: settingsRepository,
        catalog: ExerciseCatalog(modules: [_TestModule()]),
      );

      final snapshot = await loader.load(now: now);

      expect(snapshot.language, language);
      expect(snapshot.totalCards, 5);
      expect(snapshot.progressById.length, snapshot.totalCards);
      expect(snapshot.progressById[seededId]!.learned, isTrue);
      // completedToday = attempts in clusters whose lastAnswerAt is within today
      expect(snapshot.dailySummary.completedToday, 6);
      expect(snapshot.dailySessionStats.sessionsCompleted, 2);
      expect(snapshot.streakSnapshot.currentStreakDays, 3);
      expect(snapshot.allLearned, isFalse);
    },
  );
}
