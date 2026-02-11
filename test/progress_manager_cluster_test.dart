import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/language_router.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_params.dart';
import 'package:number_gym/features/training/domain/progress_manager.dart';
import 'package:number_gym/features/training/domain/training_catalog.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';
import 'package:number_gym/features/training/domain/tasks/number_pronunciation_task.dart';

import 'helpers/training_fakes.dart';

void main() {
  test(
    'clusters aggregate inside gap and create new cluster after gap',
    () async {
      final manager = _buildManager();
      const language = LearningLanguage.english;
      const cardId = TrainingItemId(type: TrainingItemType.digits, number: 0);

      await manager.loadProgress(language);

      final firstAttemptAt = DateTime(2026, 2, 7, 10, 0);
      final firstResult = await manager.recordAttempt(
        progressKey: cardId,
        isCorrect: true,
        isSkipped: false,
        language: language,
        now: firstAttemptAt,
      );

      final secondAttemptAt = firstAttemptAt.add(const Duration(minutes: 5));
      final secondResult = await manager.recordAttempt(
        progressKey: cardId,
        isCorrect: true,
        isSkipped: false,
        language: language,
        now: secondAttemptAt,
      );

      final thirdAttemptAt = secondAttemptAt.add(const Duration(minutes: 31));
      final thirdResult = await manager.recordAttempt(
        progressKey: cardId,
        isCorrect: true,
        isSkipped: false,
        language: language,
        now: thirdAttemptAt,
      );

      expect(firstResult.newCluster, isTrue);
      expect(secondResult.newCluster, isFalse);
      expect(thirdResult.newCluster, isTrue);
    },
  );

  test(
    'card becomes learned when attempts and recent accuracy reach threshold',
    () async {
      const params = LearningParams(
        dailyAttemptLimit: 50,
        dailyNewCardsLimit: 15,
        clusterMaxGapMinutes: 30,
        maxStoredClusters: 32,
        recentAttemptsWindow: 3,
        minAttemptsToLearn: 3,
        repeatCooldownCards: 0,
        easyMasteryAccuracy: 1.0,
        mediumMasteryAccuracy: 0.85,
        hardMasteryAccuracy: 0.75,
        easyTypeWeight: 1.0,
        mediumTypeWeight: 1.0,
        hardTypeWeight: 1.0,
        weaknessBoost: 2.0,
        newCardBoost: 1.0,
        recentMistakeBoost: 1.0,
        cooldownPenalty: 0.5,
      );

      final repository = InMemoryProgressRepository();
      final manager = _buildManager(
        repository: repository,
        learningParams: params,
      );
      const language = LearningLanguage.english;
      const cardId = TrainingItemId(type: TrainingItemType.digits, number: 0);

      await manager.loadProgress(language);

      final start = DateTime(2026, 2, 7, 10, 0);
      for (var i = 0; i < 3; i += 1) {
        await manager.recordAttempt(
          progressKey: cardId,
          isCorrect: true,
          isSkipped: false,
          language: language,
          now: start.add(Duration(minutes: i * 40)),
        );
      }

      final stored = repository.read(cardId, language);
      expect(stored.learned, isTrue);
      expect(stored.learnedAt, greaterThan(0));
    },
  );

  test('wrong answer can return learned card to learning state', () async {
    const params = LearningParams(
      dailyAttemptLimit: 50,
      dailyNewCardsLimit: 15,
      clusterMaxGapMinutes: 30,
      maxStoredClusters: 32,
      recentAttemptsWindow: 10,
      minAttemptsToLearn: 3,
      repeatCooldownCards: 0,
      easyMasteryAccuracy: 1.0,
      mediumMasteryAccuracy: 0.85,
      hardMasteryAccuracy: 0.75,
      easyTypeWeight: 1.0,
      mediumTypeWeight: 1.0,
      hardTypeWeight: 1.0,
      weaknessBoost: 2.0,
      newCardBoost: 1.0,
      recentMistakeBoost: 1.0,
      cooldownPenalty: 0.5,
    );

    final repository = InMemoryProgressRepository(
      seeded: {
        repoStorageKey(
          const TrainingItemId(type: TrainingItemType.digits, number: 0),
          LearningLanguage.english,
        ): const CardProgress(
          learned: true,
          clusters: <CardCluster>[
            CardCluster(
              lastAnswerAt: 1000,
              correctCount: 3,
              wrongCount: 0,
              skippedCount: 0,
            ),
          ],
          learnedAt: 1000,
          firstAttemptAt: 1000,
        ),
      },
    );

    final manager = _buildManager(
      repository: repository,
      learningParams: params,
    );
    const language = LearningLanguage.english;
    const cardId = TrainingItemId(type: TrainingItemType.digits, number: 0);

    await manager.loadProgress(language);

    await manager.recordAttempt(
      progressKey: cardId,
      isCorrect: false,
      isSkipped: false,
      language: language,
      now: DateTime(2026, 2, 8, 10, 0),
    );

    final stored = repository.read(cardId, language);
    expect(stored.learned, isFalse);
    expect(stored.learnedAt, 0);
  });

  test('learned cards are excluded from next-card selection', () async {
    const learnedId = TrainingItemId(type: TrainingItemType.digits, number: 0);
    const activeId = TrainingItemId(type: TrainingItemType.digits, number: 1);
    final repository = InMemoryProgressRepository(
      seeded: {
        repoStorageKey(learnedId, LearningLanguage.english): const CardProgress(
          learned: true,
          clusters: <CardCluster>[],
          learnedAt: 1000,
          firstAttemptAt: 1000,
        ),
      },
    );
    final manager = _buildManager(repository: repository);
    const language = LearningLanguage.english;

    await manager.loadProgress(language);

    final picked = manager.pickNextCard(
      isEligible: (_) => true,
      now: DateTime(2026, 2, 9, 12, 0),
    );
    expect(picked, isNotNull);
    expect(picked!.card.progressId, activeId);
  });

  test('hasRemainingCards is false when every card is learned', () async {
    const firstId = TrainingItemId(type: TrainingItemType.digits, number: 0);
    const secondId = TrainingItemId(type: TrainingItemType.digits, number: 1);
    final repository = InMemoryProgressRepository(
      seeded: {
        repoStorageKey(firstId, LearningLanguage.english): const CardProgress(
          learned: true,
          clusters: <CardCluster>[],
          learnedAt: 1000,
          firstAttemptAt: 1000,
        ),
        repoStorageKey(secondId, LearningLanguage.english): const CardProgress(
          learned: true,
          clusters: <CardCluster>[],
          learnedAt: 1000,
          firstAttemptAt: 1000,
        ),
      },
    );
    final manager = _buildManager(repository: repository);
    const language = LearningLanguage.english;

    await manager.loadProgress(language);

    expect(manager.hasRemainingCards, isFalse);
    expect(
      manager.pickNextCard(
        isEligible: (_) => true,
        now: DateTime(2026, 2, 9, 12, 0),
      ),
      isNull,
    );
  });

  test(
    'new cards are limited per day when there are practiced alternatives',
    () async {
      const params = LearningParams(
        dailyAttemptLimit: 50,
        dailyNewCardsLimit: 1,
        clusterMaxGapMinutes: 30,
        maxStoredClusters: 32,
        recentAttemptsWindow: 10,
        minAttemptsToLearn: 20,
        repeatCooldownCards: 0,
        easyMasteryAccuracy: 1.0,
        mediumMasteryAccuracy: 0.85,
        hardMasteryAccuracy: 0.75,
        easyTypeWeight: 1.0,
        mediumTypeWeight: 1.0,
        hardTypeWeight: 1.0,
        weaknessBoost: 2.0,
        newCardBoost: 1.0,
        recentMistakeBoost: 1.0,
        cooldownPenalty: 0.5,
      );

      final manager = _buildManager(learningParams: params);
      const language = LearningLanguage.english;
      final now = DateTime(2026, 2, 9, 12, 0);

      await manager.loadProgress(language);

      final firstPicked = manager.pickNextCard(
        isEligible: (_) => true,
        now: now,
      );
      expect(firstPicked, isNotNull);

      final firstId = firstPicked!.card.progressId;
      await manager.recordAttempt(
        progressKey: firstId,
        isCorrect: true,
        isSkipped: false,
        language: language,
        now: now,
      );

      final secondPicked = manager.pickNextCard(
        isEligible: (_) => true,
        now: now.add(const Duration(minutes: 1)),
      );
      expect(secondPicked, isNotNull);
      expect(secondPicked!.card.progressId, firstId);
    },
  );
}

ProgressManager _buildManager({
  InMemoryProgressRepository? repository,
  LearningParams? learningParams,
}) {
  final settings = FakeSettingsRepository();
  return ProgressManager(
    progressRepository: repository ?? InMemoryProgressRepository(),
    languageRouter: LanguageRouter(settingsRepository: settings),
    catalog: TrainingCatalog(
      providers: const <TrainingCardProvider>[_FixedCardsProvider()],
    ),
    learningParams: learningParams,
  );
}

class _FixedCardsProvider extends TrainingCardProvider {
  const _FixedCardsProvider();

  @override
  List<PronunciationTaskData> buildCards({
    required LearningLanguage language,
    String Function(int p1)? toWords,
  }) {
    return <PronunciationTaskData>[
      NumberPronunciationTask(
        id: const TrainingItemId(type: TrainingItemType.digits, number: 0),
        numberValue: 0,
        prompt: '0',
        language: language,
        answers: const <String>['zero', '0'],
      ),
      NumberPronunciationTask(
        id: const TrainingItemId(type: TrainingItemType.digits, number: 1),
        numberValue: 1,
        prompt: '1',
        language: language,
        answers: const <String>['one', '1'],
      ),
    ];
  }
}
