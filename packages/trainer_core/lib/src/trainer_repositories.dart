import 'daily_session_stats.dart';
import 'study_streak.dart';
import 'training/data/card_progress.dart';
import 'training/domain/learning_language.dart';

export 'daily_session_stats.dart';
export 'study_streak.dart';

abstract class ProgressRepositoryBase {
  Future<Map<String, CardProgress>> loadAll(
    List<String> storageKeys, {
    required LearningLanguage language,
  });

  Future<void> save(
    String storageKey,
    CardProgress progress, {
    required LearningLanguage language,
  });

  Future<void> reset({required LearningLanguage language});
}

abstract class SettingsRepositoryBase {
  LearningLanguage readLearningLanguage();
  Future<void> setLearningLanguage(LearningLanguage language);
  bool readPremiumPronunciationEnabled();
  Future<void> setPremiumPronunciationEnabled(bool enabled);
  bool readAutoSimulationEnabled();
  Future<void> setAutoSimulationEnabled(bool enabled);
  int readAutoSimulationContinueCount();
  Future<void> setAutoSimulationContinueCount(int count);
  int readCelebrationCounter();
  Future<void> setCelebrationCounter(int counter);
  String? readTtsVoiceId(LearningLanguage language);
  Future<void> setTtsVoiceId(LearningLanguage language, String? voiceId);
  String? readDebugForcedMode();
  Future<void> setDebugForcedMode(String? mode);
  String? readDebugForcedFamilyKey();
  Future<void> setDebugForcedFamilyKey(String? familyKey);
  DailySessionStats readDailySessionStats({DateTime? now});
  Future<void> setDailySessionStats(DailySessionStats stats);
  StudyStreak readStudyStreak();
  Future<void> setStudyStreak(StudyStreak streak);
}
