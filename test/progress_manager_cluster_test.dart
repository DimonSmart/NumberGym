import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/language_router.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_params.dart';
import 'package:number_gym/features/training/domain/progress_manager.dart';
import 'package:number_gym/features/training/domain/daily_session_stats.dart';
import 'package:number_gym/features/training/domain/repositories.dart';
import 'package:number_gym/features/training/domain/study_streak.dart';
import 'package:number_gym/features/training/domain/training_catalog.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';
import 'package:number_gym/features/training/domain/tasks/number_pronunciation_task.dart';

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
        learnedReviewProbability: 0.0,
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
      learnedReviewProbability: 0.0,
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

    final repository = _InMemoryProgressRepository(
      seeded: {
        _repoKey(
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
        learnedReviewProbability: 0.0,
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
  _InMemoryProgressRepository? repository,
  LearningParams? learningParams,
}) {
  final settings = _FakeSettingsRepository();
  return ProgressManager(
    progressRepository: repository ?? _InMemoryProgressRepository(),
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

class _InMemoryProgressRepository implements ProgressRepositoryBase {
  _InMemoryProgressRepository({Map<String, CardProgress>? seeded}) {
    if (seeded != null) {
      _storage.addAll(seeded);
    }
  }

  final Map<String, CardProgress> _storage = <String, CardProgress>{};

  @override
  Future<Map<TrainingItemId, CardProgress>> loadAll(
    List<TrainingItemId> cardIds, {
    required LearningLanguage language,
  }) async {
    final result = <TrainingItemId, CardProgress>{};
    for (final id in cardIds) {
      result[id] = _storage[_repoKey(id, language)] ?? CardProgress.empty;
    }
    return result;
  }

  @override
  Future<void> save(
    TrainingItemId cardId,
    CardProgress progress, {
    required LearningLanguage language,
  }) async {
    _storage[_repoKey(cardId, language)] = progress;
  }

  @override
  Future<void> reset({required LearningLanguage language}) async {
    final prefix = '${language.code}:';
    _storage.removeWhere((key, value) => key.startsWith(prefix));
  }

  CardProgress read(TrainingItemId cardId, LearningLanguage language) {
    return _storage[_repoKey(cardId, language)] ?? CardProgress.empty;
  }
}

String _repoKey(TrainingItemId id, LearningLanguage language) {
  return '${language.code}:${id.storageKey}';
}

class _FakeSettingsRepository implements SettingsRepositoryBase {
  LearningLanguage _language = LearningLanguage.english;
  int _answerSeconds = 10;
  int _hintStreak = 3;
  bool _premium = false;
  bool _autoSimulationEnabled = false;
  int _autoSimulationContinueCount = 0;
  int _celebrationCounter = 0;
  LearningMethod? _forcedMethod;
  TrainingItemType? _forcedItemType;
  DailySessionStats _dailySessionStats = DailySessionStats.emptyFor(
    DateTime.now(),
  );
  StudyStreak _studyStreak = StudyStreak.empty();
  final Map<LearningLanguage, String?> _voiceByLanguage =
      <LearningLanguage, String?>{};

  @override
  LearningLanguage readLearningLanguage() => _language;

  @override
  Future<void> setLearningLanguage(LearningLanguage language) async {
    _language = language;
  }

  @override
  int readAnswerDurationSeconds() => _answerSeconds;

  @override
  Future<void> setAnswerDurationSeconds(int seconds) async {
    _answerSeconds = seconds;
  }

  @override
  int readHintStreakCount() => _hintStreak;

  @override
  Future<void> setHintStreakCount(int count) async {
    _hintStreak = count;
  }

  @override
  bool readPremiumPronunciationEnabled() => _premium;

  @override
  Future<void> setPremiumPronunciationEnabled(bool enabled) async {
    _premium = enabled;
  }

  @override
  bool readAutoSimulationEnabled() => _autoSimulationEnabled;

  @override
  Future<void> setAutoSimulationEnabled(bool enabled) async {
    _autoSimulationEnabled = enabled;
  }

  @override
  int readAutoSimulationContinueCount() => _autoSimulationContinueCount;

  @override
  Future<void> setAutoSimulationContinueCount(int count) async {
    _autoSimulationContinueCount = count;
  }

  @override
  int readCelebrationCounter() => _celebrationCounter;

  @override
  Future<void> setCelebrationCounter(int counter) async {
    _celebrationCounter = counter;
  }

  @override
  DailySessionStats readDailySessionStats({DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    return _dailySessionStats.normalizedFor(resolvedNow);
  }

  @override
  Future<void> setDailySessionStats(DailySessionStats stats) async {
    _dailySessionStats = stats;
  }

  @override
  StudyStreak readStudyStreak() {
    return _studyStreak;
  }

  @override
  Future<void> setStudyStreak(StudyStreak streak) async {
    _studyStreak = streak;
  }

  @override
  String? readTtsVoiceId(LearningLanguage language) {
    return _voiceByLanguage[language];
  }

  @override
  Future<void> setTtsVoiceId(LearningLanguage language, String? voiceId) async {
    _voiceByLanguage[language] = voiceId;
  }

  @override
  LearningMethod? readDebugForcedLearningMethod() => _forcedMethod;

  @override
  Future<void> setDebugForcedLearningMethod(LearningMethod? method) async {
    _forcedMethod = method;
  }

  @override
  TrainingItemType? readDebugForcedItemType() => _forcedItemType;

  @override
  Future<void> setDebugForcedItemType(TrainingItemType? type) async {
    _forcedItemType = type;
  }
}
