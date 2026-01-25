import '../data/card_progress.dart';
import 'learning_language.dart';
import 'training_task.dart';

abstract class ProgressRepositoryBase {
  Future<Map<int, CardProgress>> loadAll(
    List<int> cardIds, {
    required LearningLanguage language,
  });
  Future<void> save(
    int cardId,
    CardProgress progress, {
    required LearningLanguage language,
  });
  Future<void> reset({required LearningLanguage language});
}

abstract class SettingsRepositoryBase {
  LearningLanguage readLearningLanguage();
  Future<void> setLearningLanguage(LearningLanguage language);
  int readAnswerDurationSeconds();
  Future<void> setAnswerDurationSeconds(int seconds);
  int readHintStreakCount();
  Future<void> setHintStreakCount(int count);
  bool readPremiumPronunciationEnabled();
  Future<void> setPremiumPronunciationEnabled(bool enabled);
  String? readTtsVoiceId(LearningLanguage language);
  Future<void> setTtsVoiceId(LearningLanguage language, String? voiceId);
  TrainingTaskKind? readDebugForcedTaskKind();
  Future<void> setDebugForcedTaskKind(TrainingTaskKind? kind);
}
