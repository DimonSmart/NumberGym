import 'dart:async';
import 'dart:math';

abstract class SoundWaveServiceBase {
  Stream<List<double>> get stream;
  void start();
  void stop();
  void reset();
  void onSoundLevel(double level);
  void dispose();
}

class SoundWaveService implements SoundWaveServiceBase {
  SoundWaveService({
    int historyLength = 32,
    Duration tick = const Duration(milliseconds: 80),
    double smoothing = 0.35,
    double rangeFloor = 12.0,
    double noiseFloor = 0.18,
    double responseCurve = 1.6,
    double gain = 1.15,
  })  : _soundHistory = List<double>.filled(historyLength, 0.0, growable: true),
        _soundHistoryTick = tick,
        _soundSmoothing = smoothing,
        _soundRangeFloor = rangeFloor,
        _soundNoiseFloor = noiseFloor,
        _soundResponseCurve = responseCurve,
        _soundGain = gain;

  final StreamController<List<double>> _streamController =
      StreamController<List<double>>.broadcast();

  final List<double> _soundHistory;
  final Duration _soundHistoryTick;
  final double _soundSmoothing;
  final double _soundRangeFloor;
  final double _soundNoiseFloor;
  final double _soundResponseCurve;
  final double _soundGain;

  Timer? _soundWaveTimer;
  double _minSoundLevel = 999;
  double _maxSoundLevel = -999;
  double _lastNormalizedSound = 0.0;
  double _smoothedSound = 0.0;
  bool _enabled = false;

  @override
  Stream<List<double>> get stream => _streamController.stream;

  @override
  void start() {
    _enabled = true;
    if (_soundWaveTimer != null) return;
    _soundWaveTimer = Timer.periodic(_soundHistoryTick, (_) {
      if (!_enabled) {
        return;
      }
      _smoothedSound += (_lastNormalizedSound - _smoothedSound) * _soundSmoothing;
      _pushSoundSample(_smoothedSound);
    });
  }

  @override
  void stop() {
    _enabled = false;
    _soundWaveTimer?.cancel();
    _soundWaveTimer = null;
  }

  @override
  void reset() {
    _minSoundLevel = 999;
    _maxSoundLevel = -999;
    _lastNormalizedSound = 0.0;
    _smoothedSound = 0.0;
    for (var i = 0; i < _soundHistory.length; i++) {
      _soundHistory[i] = 0.0;
    }
    _publishSoundHistory();
  }

  @override
  void onSoundLevel(double level) {
    if (!_enabled) {
      return;
    }
    final rawNormalized = _normalizeSoundLevel(level);
    final normalized = _applyNoiseGate(rawNormalized);

    _lastNormalizedSound = normalized;
    if (_soundWaveTimer == null) {
      _pushSoundSample(normalized);
    }
  }

  @override
  void dispose() {
    stop();
    unawaited(_streamController.close());
  }

  void _pushSoundSample(double normalized) {
    if (_soundHistory.isEmpty) {
      return;
    }
    _soundHistory.removeAt(0);
    _soundHistory.add(normalized);
    _publishSoundHistory();
  }

  void _publishSoundHistory() {
    if (_streamController.isClosed) {
      return;
    }
    if (!_streamController.hasListener) {
      return;
    }
    _streamController.add(List<double>.unmodifiable(_soundHistory));
  }

  double _applyNoiseGate(double normalized) {
    if (normalized <= _soundNoiseFloor) {
      return 0.0;
    }
    final adjusted = (normalized - _soundNoiseFloor) / (1 - _soundNoiseFloor);
    final shaped = pow(adjusted, _soundResponseCurve).toDouble();
    return (shaped * _soundGain).clamp(0.0, 1.0).toDouble();
  }

  double _normalizeSoundLevel(double level) {
    _minSoundLevel = min(_minSoundLevel, level);
    _maxSoundLevel = max(_maxSoundLevel, level);
    final range = (_maxSoundLevel - _minSoundLevel).abs();
    if (range >= _soundRangeFloor) {
      return ((level - _minSoundLevel) / range).clamp(0.0, 1.0).toDouble();
    }
    if (range >= 1e-3) {
      return ((level - _minSoundLevel) / _soundRangeFloor)
          .clamp(0.0, 1.0)
          .toDouble();
    }
    if (level < 0) {
      return ((level + 60) / 60).clamp(0.0, 1.0).toDouble();
    }
    return (level / 10).clamp(0.0, 1.0).toDouble();
  }
}
