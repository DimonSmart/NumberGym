import 'dart:async';
import 'dart:io';

import 'package:record/record.dart';

abstract class AudioRecorderServiceBase {
  bool get isRecording;
  Stream<double> get amplitudeStream;
  Future<void> start();
  Future<File?> stop();
  Future<void> cancel();
  void dispose();
}

class AudioRecorderService implements AudioRecorderServiceBase {
  AudioRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _emitAmplitude = false;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<void> start() async {
    if (_isRecording) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const AudioRecorderException('Microphone permission denied');
    }
    final tempPath = '${Directory.systemTemp.path}/number_gym_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: tempPath,
    );
    _emitAmplitude = true;
    _amplitudeSubscription ??= _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amplitude) {
          if (!_emitAmplitude) return;
          if (_amplitudeController.isClosed) return;
          _amplitudeController.add(amplitude.current);
        });
    _isRecording = true;
  }

  @override
  Future<File?> stop() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    _emitAmplitude = false;
    if (path == null) return null;
    final file = File(path);
    if (await file.exists()) return file;
    return null;
  }

  @override
  Future<void> cancel() async {
    if (!_isRecording) return;
    await _recorder.stop();
    _isRecording = false;
    _emitAmplitude = false;
  }

  @override
  void dispose() {
    unawaited(_amplitudeSubscription?.cancel());
    _amplitudeSubscription = null;
    unawaited(_amplitudeController.close());
    _recorder.dispose();
  }
}

class AudioRecorderException implements Exception {
  final String message;
  const AudioRecorderException(this.message);
  @override
  String toString() => 'AudioRecorderException: $message';
}
