import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

const _moduleId = 'test';
const _language = LearningLanguage.english;

final _digitsFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'digits',
  label: 'Digits',
  shortLabel: 'Digits',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: const Duration(seconds: 10),
  supportedModes: const <ExerciseMode>[ExerciseMode.speak],
);

class _FixedCardsModule implements TrainingModule {
  @override
  String get moduleId => _moduleId;

  @override
  String get displayName => 'Test';

  @override
  bool supportsLanguage(LearningLanguage language) => language == _language;

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) {
    return <ExerciseFamily>[_digitsFamily];
  }

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    return <ExerciseCard>[_card('0', 'zero'), _card('1', 'one')];
  }
}

class _InMemoryProgressRepository implements ProgressRepositoryBase {
  _InMemoryProgressRepository({Map<String, CardProgress>? seeded})
    : _storage = <String, CardProgress>{...?seeded};

  final Map<String, CardProgress> _storage;

  CardProgress read(String storageKey) {
    return _storage[storageKey] ?? CardProgress.empty;
  }

  @override
  Future<Map<String, CardProgress>> loadAll(
    List<String> storageKeys, {
    required LearningLanguage language,
  }) async {
    return <String, CardProgress>{
      for (final storageKey in storageKeys) storageKey: read(storageKey),
    };
  }

  @override
  Future<void> save(
    String storageKey,
    CardProgress progress, {
    required LearningLanguage language,
  }) async {
    _storage[storageKey] = progress;
  }

  @override
  Future<void> reset({required LearningLanguage language}) async {
    _storage.clear();
  }
}

void main() {
  test(
    'clusters aggregate inside gap and create new cluster after gap',
    () async {
      final manager = _buildManager();
      const cardId = ExerciseId(
        moduleId: _moduleId,
        familyId: 'digits',
        variantId: '0',
      );

      await manager.loadProgress(_language);

      final firstAttemptAt = DateTime(2026, 2, 7, 10, 0);
      final firstResult = await manager.recordAttempt(
        progressKey: cardId,
        isCorrect: true,
        isSkipped: false,
        language: _language,
        now: firstAttemptAt,
      );

      final secondAttemptAt = firstAttemptAt.add(const Duration(minutes: 5));
      final secondResult = await manager.recordAttempt(
        progressKey: cardId,
        isCorrect: true,
        isSkipped: false,
        language: _language,
        now: secondAttemptAt,
      );

      final thirdAttemptAt = secondAttemptAt.add(const Duration(minutes: 31));
      final thirdResult = await manager.recordAttempt(
        progressKey: cardId,
        isCorrect: true,
        isSkipped: false,
        language: _language,
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
      final repository = _InMemoryProgressRepository();
      final manager = _buildManager(
        repository: repository,
        learningParams: params,
      );
      const cardId = ExerciseId(
        moduleId: _moduleId,
        familyId: 'digits',
        variantId: '0',
      );

      await manager.loadProgress(_language);

      final start = DateTime(2026, 2, 7, 10, 0);
      for (var i = 0; i < 3; i += 1) {
        await manager.recordAttempt(
          progressKey: cardId,
          isCorrect: true,
          isSkipped: false,
          language: _language,
          now: start.add(Duration(minutes: i * 40)),
        );
      }

      final stored = repository.read(cardId.storageKey);
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
    const cardId = ExerciseId(
      moduleId: _moduleId,
      familyId: 'digits',
      variantId: '0',
    );
    final repository = _InMemoryProgressRepository(
      seeded: <String, CardProgress>{
        cardId.storageKey: const CardProgress(
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

    await manager.loadProgress(_language);
    await manager.recordAttempt(
      progressKey: cardId,
      isCorrect: false,
      isSkipped: false,
      language: _language,
      now: DateTime(2026, 2, 8, 10, 0),
    );

    final stored = repository.read(cardId.storageKey);
    expect(stored.learned, isFalse);
    expect(stored.learnedAt, 0);
  });

  test('consecutive correct progress resets after a mistake', () async {
    final manager = _buildManager();
    const cardId = ExerciseId(
      moduleId: _moduleId,
      familyId: 'digits',
      variantId: '0',
    );

    await manager.loadProgress(_language);

    final start = DateTime(2026, 2, 9, 10, 0);
    await manager.recordAttempt(
      progressKey: cardId,
      isCorrect: true,
      isSkipped: false,
      language: _language,
      now: start,
    );
    await manager.recordAttempt(
      progressKey: cardId,
      isCorrect: true,
      isSkipped: false,
      language: _language,
      now: start.add(const Duration(minutes: 1)),
    );
    expect(manager.progressFor(cardId).consecutiveCorrect, 2);

    await manager.recordAttempt(
      progressKey: cardId,
      isCorrect: false,
      isSkipped: false,
      language: _language,
      now: start.add(const Duration(minutes: 2)),
    );
    expect(manager.progressFor(cardId).consecutiveCorrect, 0);

    await manager.recordAttempt(
      progressKey: cardId,
      isCorrect: true,
      isSkipped: false,
      language: _language,
      now: start.add(const Duration(minutes: 3)),
    );
    expect(manager.progressFor(cardId).consecutiveCorrect, 1);
  });

  test('learned cards are excluded from next-card selection', () async {
    const learnedId = ExerciseId(
      moduleId: _moduleId,
      familyId: 'digits',
      variantId: '0',
    );
    const activeId = ExerciseId(
      moduleId: _moduleId,
      familyId: 'digits',
      variantId: '1',
    );
    final repository = _InMemoryProgressRepository(
      seeded: <String, CardProgress>{
        learnedId.storageKey: const CardProgress(
          learned: true,
          clusters: <CardCluster>[],
          learnedAt: 1000,
          firstAttemptAt: 1000,
        ),
      },
    );
    final manager = _buildManager(repository: repository);

    await manager.loadProgress(_language);

    final picked = manager.pickNextCard(
      isEligible: (_) => true,
      now: DateTime(2026, 2, 9, 12, 0),
    );
    expect(picked, isNotNull);
    expect(picked!.progressId, activeId);
  });

  test('hasRemainingCards is false when every card is learned', () async {
    const firstId = ExerciseId(
      moduleId: _moduleId,
      familyId: 'digits',
      variantId: '0',
    );
    const secondId = ExerciseId(
      moduleId: _moduleId,
      familyId: 'digits',
      variantId: '1',
    );
    final repository = _InMemoryProgressRepository(
      seeded: <String, CardProgress>{
        firstId.storageKey: const CardProgress(
          learned: true,
          clusters: <CardCluster>[],
          learnedAt: 1000,
          firstAttemptAt: 1000,
        ),
        secondId.storageKey: const CardProgress(
          learned: true,
          clusters: <CardCluster>[],
          learnedAt: 1000,
          firstAttemptAt: 1000,
        ),
      },
    );
    final manager = _buildManager(repository: repository);

    await manager.loadProgress(_language);

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

      await manager.loadProgress(_language);

      final now = DateTime(2026, 2, 9, 12, 0);
      final firstPicked = manager.pickNextCard(
        isEligible: (_) => true,
        now: now,
      );

      expect(firstPicked, isNotNull);

      await manager.recordAttempt(
        progressKey: firstPicked!.progressId,
        isCorrect: true,
        isSkipped: false,
        language: _language,
        now: now,
      );

      final secondPicked = manager.pickNextCard(
        isEligible: (_) => true,
        now: now.add(const Duration(minutes: 1)),
      );
      expect(secondPicked, isNotNull);
      expect(secondPicked!.progressId, firstPicked.progressId);
    },
  );
}

ProgressManager _buildManager({
  _InMemoryProgressRepository? repository,
  LearningParams? learningParams,
}) {
  return ProgressManager(
    progressRepository: repository ?? _InMemoryProgressRepository(),
    catalog: ExerciseCatalog(modules: <TrainingModule>[_FixedCardsModule()]),
    learningParams: learningParams,
  );
}

ExerciseCard _card(String variantId, String spoken) {
  final id = ExerciseId(
    moduleId: _moduleId,
    familyId: _digitsFamily.id,
    variantId: variantId,
  );
  return ExerciseCard(
    id: id,
    family: _digitsFamily,
    language: _language,
    displayText: variantId,
    promptText: variantId,
    acceptedAnswers: <String>[spoken, variantId],
    celebrationText: '$variantId -> $spoken',
  );
}
