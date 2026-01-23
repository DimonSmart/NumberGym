import 'training_services.dart';

class StreakTracker {
  int _streak = 0;

  int get streak => _streak;

  void reset() {
    _streak = 0;
  }

  void record(bool correct) {
    if (correct) {
      _streak += 1;
    } else {
      _streak = 0;
    }
  }
}

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

  bool get shouldPause => _streak >= threshold;
}

class InternetGate {
  InternetGate({
    required InternetChecker checker,
    Duration cache = const Duration(seconds: 10),
    bool initialValue = true,
  })  : _checker = checker,
        _cache = cache,
        _hasInternet = initialValue;

  final InternetChecker _checker;
  final Duration _cache;
  bool _hasInternet;
  DateTime? _lastCheck;

  bool get hasInternet => _hasInternet;

  Future<void> refresh({bool force = false}) async {
    if (!force && _lastCheck != null) {
      final elapsed = DateTime.now().difference(_lastCheck!);
      if (elapsed < _cache) {
        return;
      }
    }
    _lastCheck = DateTime.now();
    _hasInternet = await _checker();
  }
}
