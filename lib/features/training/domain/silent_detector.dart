class SilentDetector {
  SilentDetector({this.threshold = 3});

  final int threshold;
  int _streak = 0;

  int get streak => _streak;

  void reset() {
    _streak = 0;
  }

  void record({required bool interacted, required bool affectsProgress}) {
    if (!affectsProgress) {
      return;
    }
    if (interacted) {
      _streak = 0;
    } else {
      _streak += 1;
    }
  }

  bool get shouldStop => _streak >= threshold;
}
