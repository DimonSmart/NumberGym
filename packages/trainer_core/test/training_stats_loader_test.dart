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

const _conceptStatsModuleId = 'concept_stats';

final _presentFamily = ExerciseFamily(
  moduleId: _conceptStatsModuleId,
  id: 'present',
  label: 'Present',
  shortLabel: 'Present',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.chooseFromPrompt],
);

final _pastFamily = ExerciseFamily(
  moduleId: _conceptStatsModuleId,
  id: 'past',
  label: 'Past',
  shortLabel: 'Past',
  difficultyTier: ExerciseDifficultyTier.medium,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.chooseFromPrompt],
);

const _conceptA = ExerciseConcept(
  id: 'concept_a',
  label: 'Concept A',
  secondaryLabel: 'Base concept A',
);

const _conceptB = ExerciseConcept(
  id: 'concept_b',
  label: 'Concept B',
  secondaryLabel: 'Base concept B',
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

class _ConceptStatsModule implements TrainingModule {
  @override
  String get moduleId => _conceptStatsModuleId;

  @override
  String get displayName => 'Concept stats';

  @override
  bool supportsLanguage(LearningLanguage language) =>
      language == LearningLanguage.english;

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) => [
    _presentFamily,
    _pastFamily,
  ];

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    return [
      _card(
        family: _presentFamily,
        concept: _conceptA,
        variantId: 'concept_a::first',
        language: language,
      ),
      _card(
        family: _presentFamily,
        concept: _conceptA,
        variantId: 'concept_a::second',
        language: language,
      ),
      _card(
        family: _presentFamily,
        concept: _conceptB,
        variantId: 'concept_b::first',
        language: language,
      ),
      _card(
        family: _pastFamily,
        concept: _conceptA,
        variantId: 'concept_a::first',
        language: language,
      ),
    ];
  }

  ExerciseCard _card({
    required ExerciseFamily family,
    required ExerciseConcept concept,
    required String variantId,
    required LearningLanguage language,
  }) {
    final id = ExerciseId(
      moduleId: moduleId,
      familyId: family.id,
      variantId: variantId,
    );
    return ExerciseCard(
      id: id,
      family: family,
      language: language,
      displayText: variantId,
      promptText: variantId,
      acceptedAnswers: [variantId],
      celebrationText: variantId,
      concept: concept,
      chooseFromPrompt: ChoiceExerciseSpec(
        prompt: variantId,
        correctOption: variantId,
        options: [variantId, 'other_1', 'other_2', 'other_3'],
      ),
    );
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
      expect(snapshot.baseLanguage, LearningLanguage.english);
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

  test('load groups concept progress by family and concept', () async {
    final now = DateTime(2026, 2, 10, 14, 15);
    const language = LearningLanguage.english;
    final progressRepository = InMemoryProgressRepository();

    Future<void> saveLearned(String familyId, String variantId) async {
      final id = ExerciseId(
        moduleId: _conceptStatsModuleId,
        familyId: familyId,
        variantId: variantId,
      );
      await progressRepository.save(
        id.storageKey,
        _learnedProgress(now),
        language: language,
      );
    }

    await saveLearned('present', 'concept_a::first');
    await saveLearned('present', 'concept_b::first');
    await saveLearned('past', 'concept_a::first');

    final loader = TrainingStatsLoader(
      progressRepository: progressRepository,
      settingsRepository: FakeSettingsRepository(language: language),
      catalog: ExerciseCatalog(modules: [_ConceptStatsModule()]),
    );

    final snapshot = await loader.load(now: now);

    expect(snapshot.totalConcepts, 3);
    expect(snapshot.learnedConceptCount, 2);

    final present = snapshot.familyProgress.singleWhere(
      (family) => family.family.id == 'present',
    );
    expect(present.totalCards, 3);
    expect(present.learnedCards, 2);
    expect(present.totalConcepts, 2);
    expect(present.learnedConcepts, 1);

    final presentConceptA = present.concepts.singleWhere(
      (concept) => concept.concept.id == 'concept_a',
    );
    expect(presentConceptA.totalCards, 2);
    expect(presentConceptA.learnedCards, 1);
    expect(presentConceptA.learned, isFalse);

    final presentConceptB = present.concepts.singleWhere(
      (concept) => concept.concept.id == 'concept_b',
    );
    expect(presentConceptB.learned, isTrue);

    final past = snapshot.familyProgress.singleWhere(
      (family) => family.family.id == 'past',
    );
    final pastConceptA = past.concepts.singleWhere(
      (concept) => concept.concept.id == 'concept_a',
    );
    expect(pastConceptA.totalCards, 1);
    expect(pastConceptA.learnedCards, 1);
    expect(pastConceptA.learned, isTrue);
  });
}

CardProgress _learnedProgress(DateTime now) {
  final timestamp = now.millisecondsSinceEpoch;
  return CardProgress(
    learned: true,
    clusters: <CardCluster>[
      CardCluster(
        lastAnswerAt: timestamp,
        correctCount: 20,
        wrongCount: 0,
        skippedCount: 0,
      ),
    ],
    learnedAt: timestamp,
    firstAttemptAt: timestamp,
    consecutiveCorrect: 20,
  );
}
