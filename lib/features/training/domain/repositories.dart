import '../data/card_progress.dart';
import 'learning_language.dart';

abstract class ProgressRepositoryBase {
  Future<Map<int, CardProgress>> loadAll({required int maxCardId});
  Future<void> save(int cardId, CardProgress progress);
  Future<void> reset();
}

abstract class SettingsRepositoryBase {
  LearningLanguage readLearningLanguage();
  Future<void> setLearningLanguage(LearningLanguage language);
  int readAnswerDurationSeconds();
  Future<void> setAnswerDurationSeconds(int seconds);
}
