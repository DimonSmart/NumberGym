import 'training_services.dart';

class InternetGate {
  InternetGate({
    required InternetChecker checker,
    Duration cache = const Duration(seconds: 10),
    bool initialValue = true,
  }) : _checker = checker,
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
