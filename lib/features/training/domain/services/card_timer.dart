import 'dart:async';

abstract class CardTimerBase {
  Duration get duration;
  bool get isRunning;
  void start(Duration duration, void Function() onTimeout);
  Duration remaining();
  void stop();
  void dispose();
}

class CardTimer implements CardTimerBase {
  Timer? _timer;
  DateTime? _startTime;
  Duration _duration = Duration.zero;

  @override
  Duration get duration => _duration;

  @override
  bool get isRunning => _timer?.isActive ?? false;

  @override
  void start(Duration duration, void Function() onTimeout) {
    _timer?.cancel();
    _duration = duration;
    _startTime = DateTime.now();
    _timer = Timer(duration, onTimeout);
  }

  @override
  Duration remaining() {
    if (_startTime == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_startTime!);
    final remaining = _duration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
  }

  @override
  void dispose() {
    stop();
  }
}
