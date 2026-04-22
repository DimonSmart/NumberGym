import 'package:hive/hive.dart';

import '../domain/learning_language.dart';
import '../domain/repositories.dart';
import '../domain/training_item.dart';
import 'card_progress.dart';

class ProgressRepository implements ProgressRepositoryBase {
  final Box<CardProgress> progressBox;

  ProgressRepository(this.progressBox);

  @override
  Future<Map<TrainingItemId, CardProgress>> loadAll(
    List<TrainingItemId> cardIds, {
    required LearningLanguage language,
  }) async {
    final results = <TrainingItemId, CardProgress>{};
    for (final id in cardIds) {
      results[id] = await _readProgress(id, language);
    }
    return results;
  }

  @override
  Future<void> save(
    TrainingItemId cardId,
    CardProgress progress, {
    required LearningLanguage language,
  }) async {
    await progressBox.put(_cardKey(cardId, language), progress);
  }

  @override
  Future<void> reset({required LearningLanguage language}) async {
    final scopedPrefix = _cardKeyPrefix(language);
    final keysToDelete = progressBox.keys.where((key) {
      if (key is! String) return false;
      return key.startsWith(scopedPrefix);
    }).toList();
    if (keysToDelete.isEmpty) return;
    await progressBox.deleteAll(keysToDelete);
  }

  Future<CardProgress> _readProgress(
    TrainingItemId id,
    LearningLanguage language,
  ) async {
    final scopedKey = _cardKey(id, language);
    final scopedProgress = progressBox.get(scopedKey);
    if (scopedProgress != null) return scopedProgress;

    return CardProgress.empty;
  }

  String _cardKey(TrainingItemId id, LearningLanguage language) {
    return '${_cardKeyPrefix(language)}${id.storageKey}';
  }

  String _cardKeyPrefix(LearningLanguage language) {
    return 'card_${language.code}_';
  }

}
