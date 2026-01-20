import 'package:hive/hive.dart';

import '../domain/repositories.dart';
import 'card_progress.dart';

class ProgressRepository implements ProgressRepositoryBase {
  final Box<CardProgress> progressBox;

  ProgressRepository(this.progressBox);

  @override
  Future<Map<int, CardProgress>> loadAll({required int maxCardId}) async {
    final results = <int, CardProgress>{};
    for (var id = 0; id <= maxCardId; id++) {
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
