import 'package:hive/hive.dart';

import '../domain/learning_language.dart';
import '../domain/repositories.dart';
import 'card_progress.dart';

class ProgressRepository implements ProgressRepositoryBase {
  final Box<CardProgress> progressBox;

  ProgressRepository(this.progressBox);

  @override
  Future<Map<int, CardProgress>> loadAll(
    List<int> cardIds, {
    required LearningLanguage language,
  }) async {
    final results = <int, CardProgress>{};
    for (final id in cardIds) {
      results[id] = await _readProgress(id, language);
    }
    return results;
  }

  @override
  Future<void> save(
    int cardId,
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
      return key.startsWith(scopedPrefix) || _isLegacyKey(key);
    }).toList();
    if (keysToDelete.isEmpty) return;
    await progressBox.deleteAll(keysToDelete);
  }

  Future<CardProgress> _readProgress(
    int id,
    LearningLanguage language,
  ) async {
    final scopedKey = _cardKey(id, language);
    final scopedProgress = progressBox.get(scopedKey);
    if (scopedProgress != null) return scopedProgress;

    final legacyKey = _legacyCardKey(id);
    final legacyProgress = progressBox.get(legacyKey);
    if (legacyProgress != null) {
      await progressBox.put(scopedKey, legacyProgress);
      await progressBox.delete(legacyKey);
      return legacyProgress;
    }

    return CardProgress.empty;
  }

  String _cardKey(int id, LearningLanguage language) {
    return '${_cardKeyPrefix(language)}$id';
  }

  String _cardKeyPrefix(LearningLanguage language) {
    return 'card_${language.code}_';
  }

  String _legacyCardKey(int id) => 'card_$id';

  static final RegExp _legacyKeyPattern = RegExp(r'^card_\d+$');

  bool _isLegacyKey(String key) {
    return _legacyKeyPattern.hasMatch(key);
  }
}
