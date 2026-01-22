import '../data/card_progress.dart';
import 'learning_language.dart';

abstract class ProgressRepositoryBase {
  Future<Map<int, CardProgress>> loadAll(List<int> cardIds);
  Future<void> save(int cardId, CardProgress progress);
  Future<void> reset();
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
}
