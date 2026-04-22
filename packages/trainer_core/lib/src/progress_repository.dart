import 'package:hive/hive.dart';

import 'trainer_repositories.dart';
import 'training/data/card_progress.dart';
import 'training/domain/learning_language.dart';

class ProgressRepository implements ProgressRepositoryBase {
  ProgressRepository(this.progressBox);

  final Box<CardProgress> progressBox;

  @override
  Future<Map<String, CardProgress>> loadAll(
    List<String> storageKeys, {
    required LearningLanguage language,
  }) async {
    final results = <String, CardProgress>{};
    for (final storageKey in storageKeys) {
      results[storageKey] = await _readProgress(storageKey, language);
    }
    return results;
  }

  @override
  Future<void> save(
    String storageKey,
    CardProgress progress, {
    required LearningLanguage language,
  }) async {
    await progressBox.put(_cardKey(storageKey, language), progress);
  }

  @override
  Future<void> reset({required LearningLanguage language}) async {
    final prefix = _cardKeyPrefix(language);
    final keysToDelete = progressBox.keys.where((key) {
      return key is String && key.startsWith(prefix);
    }).toList();
    if (keysToDelete.isEmpty) {
      return;
    }
    await progressBox.deleteAll(keysToDelete);
  }

  Future<CardProgress> _readProgress(
    String storageKey,
    LearningLanguage language,
  ) async {
    return progressBox.get(_cardKey(storageKey, language)) ?? CardProgress.empty;
  }

  String _cardKey(String storageKey, LearningLanguage language) {
    return '${_cardKeyPrefix(language)}$storageKey';
  }

  String _cardKeyPrefix(LearningLanguage language) {
    return 'card_language=${language.code}_';
  }
}
