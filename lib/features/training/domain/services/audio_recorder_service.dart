import 'dart:io';

import 'package:record/record.dart';

abstract class AudioRecorderServiceBase {
  bool get isRecording;
  Future<void> start();
  Future<File?> stop();
  Future<void> cancel();
  void dispose();
}

class AudioRecorderService implements AudioRecorderServiceBase {
  AudioRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

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
    _isRecording = true;
  }

  @override
  Future<File?> stop() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
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
  }

  @override
  void dispose() {
    _recorder.dispose();
  }
}

class AudioRecorderException implements Exception {
  final String message;
  const AudioRecorderException(this.message);
  @override
  String toString() => 'AudioRecorderException: $message';
}
