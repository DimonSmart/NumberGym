import 'package:hive/hive.dart';

import '../domain/repositories.dart';
import 'card_progress.dart';

class ProgressRepository implements ProgressRepositoryBase {
  final Box<CardProgress> progressBox;

  ProgressRepository(this.progressBox);

  @override
  Future<Map<int, CardProgress>> loadAll(List<int> cardIds) async {
    final results = <int, CardProgress>{};
    for (final id in cardIds) {
      final key = _cardKey(id);
      final progress = progressBox.get(key) ?? CardProgress.empty;
      results[id] = progress;
    }
    return results;
  }

  @override
  Future<void> save(int cardId, CardProgress progress) async {
    await progressBox.put(_cardKey(cardId), progress);
  }

  @override
  Future<void> reset() async {
    await progressBox.clear();
  }

  String _cardKey(int id) => 'card_$id';
}
