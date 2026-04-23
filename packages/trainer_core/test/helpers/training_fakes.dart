import 'package:trainer_core/trainer_core.dart';

class FakeSettingsRepository implements SettingsRepositoryBase {
  FakeSettingsRepository({
    LearningLanguage language = LearningLanguage.english,
    Map<LearningLanguage, DailySessionStats>? dailySessionStatsByLanguage,
    Map<LearningLanguage, StudyStreak>? streakByLanguage,
  }) : _language = language,
       _dailySessionStatsByLanguage =
           dailySessionStatsByLanguage ??
           <LearningLanguage, DailySessionStats>{},
       _streakByLanguage =
           streakByLanguage ?? <LearningLanguage, StudyStreak>{};

  LearningLanguage _language;
  final Map<LearningLanguage, DailySessionStats> _dailySessionStatsByLanguage;
  final Map<LearningLanguage, StudyStreak> _streakByLanguage;

  @override
  LearningLanguage readLearningLanguage() => _language;

  @override
  Future<void> setLearningLanguage(LearningLanguage language) async {
    _language = language;
  }

  @override
  DailySessionStats readDailySessionStats({DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final stats = _dailySessionStatsByLanguage[_language];
    if (stats == null) {
      return DailySessionStats.emptyFor(resolvedNow);
    }
    return stats.normalizedFor(resolvedNow);
  }

  @override
  Future<void> setDailySessionStats(DailySessionStats stats) async {
    _dailySessionStatsByLanguage[_language] = stats;
  }

  @override
  StudyStreak readStudyStreak() {
    return _streakByLanguage[_language] ?? StudyStreak.empty();
  }

  @override
  Future<void> setStudyStreak(StudyStreak streak) async {
    _streakByLanguage[_language] = streak;
  }

  @override
  bool readPremiumPronunciationEnabled() => false;

  @override
  Future<void> setPremiumPronunciationEnabled(bool enabled) async {}

  @override
  bool readAutoSimulationEnabled() => false;

  @override
  Future<void> setAutoSimulationEnabled(bool enabled) async {}

  @override
  int readAutoSimulationContinueCount() => 0;

  @override
  Future<void> setAutoSimulationContinueCount(int count) async {}

  @override
  int readCelebrationCounter() => 0;

  @override
  Future<void> setCelebrationCounter(int counter) async {}

  @override
  String? readTtsVoiceId(LearningLanguage language) => null;

  @override
  Future<void> setTtsVoiceId(LearningLanguage language, String? voiceId) async {}

  @override
  String? readDebugForcedMode() => null;

  @override
  Future<void> setDebugForcedMode(String? mode) async {}

  @override
  String? readDebugForcedFamilyKey() => null;

  @override
  Future<void> setDebugForcedFamilyKey(String? familyKey) async {}
}
