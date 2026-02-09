import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/daily_session_stats.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/repositories.dart';
import 'package:number_gym/features/training/domain/study_streak.dart';
import 'package:number_gym/features/training/domain/study_streak_service.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';

void main() {
  test('streak resets to zero after a skipped day', () {
    final streak = StudyStreak(
      sessionsByDay: const <String, int>{
        '2026-02-05': 1,
        '2026-02-06': 1,
        '2026-02-07': 1,
      },
    );

    final streakDays = streak.currentStreakDays(now: DateTime(2026, 2, 9, 10));
    expect(streakDays, 0);
  });

  test('streak continues from yesterday when today has no sessions yet', () {
    final streak = StudyStreak(
      sessionsByDay: const <String, int>{
        '2026-02-06': 1,
        '2026-02-07': 1,
        '2026-02-08': 1,
      },
    );

    final streakDays = streak.currentStreakDays(now: DateTime(2026, 2, 9, 10));
    expect(streakDays, 3);
  });

  test('completed sessions are accumulated per day', () {
    var streak = StudyStreak.empty();

    streak = streak.addCompletedSession(now: DateTime(2026, 2, 9, 8, 0));
    streak = streak.addCompletedSession(now: DateTime(2026, 2, 9, 20, 0));
    streak = streak.addCompletedSession(now: DateTime(2026, 2, 10, 9, 0));

    expect(streak.sessionsByDay['2026-02-09'], 2);
    expect(streak.sessionsByDay['2026-02-10'], 1);
  });

  test('service snapshot marks days with multiple sessions', () {
    final repository = _FakeSettingsRepository(
      streak: StudyStreak(
        sessionsByDay: const <String, int>{
          '2026-02-01': 1,
          '2026-02-02': 2,
          '2026-02-09': 1,
        },
      ),
    );
    final service = StudyStreakService(settingsRepository: repository);

    final snapshot = service.readCurrentStreakSnapshot(
      now: DateTime(2026, 2, 9, 12, 0),
    );

    expect(snapshot.currentStreakDays, 1);
    expect(snapshot.monthDays.length, 28);
    expect(snapshot.monthDays[1].hasActivity, isTrue);
    expect(snapshot.monthDays[1].hasMultipleSessions, isTrue);
    expect(snapshot.monthDays[2].hasActivity, isFalse);
  });
}

class _FakeSettingsRepository implements SettingsRepositoryBase {
  _FakeSettingsRepository({StudyStreak? streak})
    : _studyStreak = streak ?? StudyStreak.empty();

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
  StudyStreak _studyStreak;
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
