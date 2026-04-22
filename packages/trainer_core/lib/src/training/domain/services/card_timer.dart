import 'dart:async';

abstract class CardTimerBase {
  Duration get duration;
  bool get isRunning;
  void start(Duration duration, void Function() onTimeout);
  Duration remaining();
  void pause();
  void resume();
  void stop();
  void dispose();
}

class CardTimer implements CardTimerBase {
  Timer? _timer;
  DateTime? _startTime;
  Duration _duration = Duration.zero;
  Duration _pausedRemaining = Duration.zero;
  void Function()? _onTimeout;

  @override
  Duration get duration => _duration;

  @override
  bool get isRunning => _timer?.isActive ?? false;

  @override
  void start(Duration duration, void Function() onTimeout) {
    stop();
    _duration = duration;
    _pausedRemaining = duration;
    _onTimeout = onTimeout;
    _startInternal(duration);
  }

  @override
  Duration remaining() {
    if (_startTime == null) {
      return _pausedRemaining;
    }
    final elapsed = DateTime.now().difference(_startTime!);
    final remaining = _duration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  void pause() {
    if (!isRunning) return;
    _pausedRemaining = remaining();
    _timer?.cancel();
    _timer = null;
    _startTime = null;
  }

  @override
  void resume() {
    if (isRunning) return;
    if (_onTimeout == null || _pausedRemaining <= Duration.zero) return;
    _startInternal(_pausedRemaining);
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
    _pausedRemaining = Duration.zero;
    _onTimeout = null;
  }

  @override
  void dispose() {
    stop();
  }

  void _startInternal(Duration remaining) {
    _pausedRemaining = remaining;
    _startTime = DateTime.now();
    _timer = Timer(remaining, () {
      final callback = _onTimeout;
      _timer = null;
      _startTime = null;
      _pausedRemaining = Duration.zero;
      _onTimeout = null;
      callback?.call();
    });
  }
}
