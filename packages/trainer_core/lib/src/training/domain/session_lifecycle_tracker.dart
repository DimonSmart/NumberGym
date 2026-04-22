import 'dart:math' as math;

class SessionLifecycleTracker {
  DateTime? _startedAt;
  int _cardsCompleted = 0;
  int _targetCards = 0;
  bool _statsPersisted = false;

  DateTime? get startedAt => _startedAt;
  int get cardsCompleted => _cardsCompleted;
  int get targetCards => _targetCards;
  bool get hasCompletedCards => _cardsCompleted > 0;
  bool get statsPersisted => _statsPersisted;
  bool get reachedLimit => _cardsCompleted >= _targetCards;

  void reset({required int targetCards, DateTime? now}) {
    _startedAt = now ?? DateTime.now();
    _cardsCompleted = 0;
    _targetCards = targetCards < 0 ? 0 : targetCards;
    _statsPersisted = false;
  }

  void incrementCompleted() {
    _cardsCompleted += 1;
  }

  Duration elapsed({DateTime? now}) {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    final resolvedNow = now ?? DateTime.now();
    final diff = resolvedNow.difference(startedAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  int celebrationTargetCards() {
    if (_targetCards > 0) {
      return _targetCards;
    }
    return math.max(1, _cardsCompleted);
  }

  void markStatsPersisted() {
    _statsPersisted = true;
  }
}
