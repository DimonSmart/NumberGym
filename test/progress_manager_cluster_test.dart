import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/language_router.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/progress_manager.dart';
import 'package:number_gym/features/training/domain/repositories.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';

void main() {
  test('scheduler applies only when a new cluster is created', () async {
    final settings = _FakeSettingsRepository();
    final repository = _InMemoryProgressRepository();
    final manager = ProgressManager(
      progressRepository: repository,
      languageRouter: LanguageRouter(settingsRepository: settings),
    );
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
    final afterFirst = repository.read(cardId, language);

    expect(firstResult.newCluster, isTrue);
    expect(firstResult.clusterApplied, isTrue);
    expect(afterFirst.totalAttempts, 1);

    final secondAttemptAt = firstAttemptAt.add(const Duration(minutes: 5));
    final secondResult = await manager.recordAttempt(
      progressKey: cardId,
      isCorrect: true,
      isSkipped: false,
      language: language,
      now: secondAttemptAt,
    );
    final afterSecond = repository.read(cardId, language);

    expect(secondResult.newCluster, isFalse);
    expect(secondResult.clusterApplied, isFalse);
    expect(afterSecond.totalAttempts, 2);
    expect(afterSecond.intervalDays, afterFirst.intervalDays);
    expect(afterSecond.nextDue, greaterThan(afterFirst.nextDue));
    expect(afterSecond.spacedSuccessCount, afterFirst.spacedSuccessCount);

    final thirdAttemptAt = secondAttemptAt.add(const Duration(minutes: 31));
    final thirdResult = await manager.recordAttempt(
      progressKey: cardId,
      isCorrect: true,
      isSkipped: false,
      language: language,
      now: thirdAttemptAt,
    );
    final afterThird = repository.read(cardId, language);

    expect(thirdResult.newCluster, isTrue);
    expect(thirdResult.clusterApplied, isTrue);
    expect(afterThird.totalAttempts, 3);
    expect(afterThird.intervalDays, greaterThan(afterSecond.intervalDays));
    expect(afterThird.nextDue, greaterThan(afterSecond.nextDue));
  });
}

class _InMemoryProgressRepository implements ProgressRepositoryBase {
  final Map<String, CardProgress> _storage = <String, CardProgress>{};

  @override
  Future<Map<TrainingItemId, CardProgress>> loadAll(
    List<TrainingItemId> cardIds, {
    required LearningLanguage language,
  }) async {
    final result = <TrainingItemId, CardProgress>{};
    for (final id in cardIds) {
      result[id] = _storage[_key(id, language)] ?? CardProgress.empty;
    }
    return result;
  }

  @override
  Future<void> save(
    TrainingItemId cardId,
    CardProgress progress, {
    required LearningLanguage language,
  }) async {
    _storage[_key(cardId, language)] = progress;
  }

  @override
  Future<void> reset({required LearningLanguage language}) async {
    final prefix = '${language.code}:';
    _storage.removeWhere((key, value) => key.startsWith(prefix));
  }

  CardProgress read(TrainingItemId cardId, LearningLanguage language) {
    return _storage[_key(cardId, language)] ?? CardProgress.empty;
  }

  String _key(TrainingItemId id, LearningLanguage language) {
    return '${language.code}:${id.storageKey}';
  }
}

class _FakeSettingsRepository implements SettingsRepositoryBase {
  LearningLanguage _language = LearningLanguage.english;
  int _answerSeconds = 10;
  int _hintStreak = 3;
  bool _premium = false;
  LearningMethod? _forcedMethod;
  TrainingItemType? _forcedItemType;
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
