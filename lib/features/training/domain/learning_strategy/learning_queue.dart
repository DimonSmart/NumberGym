import '../training_item.dart';

class LearningQueue {
  LearningQueue({
    required List<TrainingItemId> allCards,
    required int activeLimit,
  })  : _allCards = List<TrainingItemId>.unmodifiable(allCards),
        _activeLimit = activeLimit;

  final List<TrainingItemId> _allCards;
  final int _activeLimit;
  final List<TrainingItemId> _backlog = <TrainingItemId>[];
  final List<TrainingItemId> _active = <TrainingItemId>[];

  List<TrainingItemId> get allCards => _allCards;
  List<TrainingItemId> get backlog => List<TrainingItemId>.unmodifiable(_backlog);
  List<TrainingItemId> get active => List<TrainingItemId>.unmodifiable(_active);

  int get activeLimit => _activeLimit;
  int get activeCount => _active.length;
  int get backlogCount => _backlog.length;
  bool get hasRemaining => _active.isNotEmpty || _backlog.isNotEmpty;

  void reset({required List<TrainingItemId> unlearned}) {
    _backlog
      ..clear()
      ..addAll(unlearned);
    _active.clear();
    fillActive();
  }

  void fillActive() {
    while (_active.length < _activeLimit && _backlog.isNotEmpty) {
      _active.add(_backlog.removeAt(0));
    }
  }

  bool removeFromActive(TrainingItemId id) {
    return _active.remove(id);
  }

  TrainingItemId? pullNextFromBacklog() {
    if (_backlog.isEmpty) return null;
    return _backlog.removeAt(0);
  }
}
