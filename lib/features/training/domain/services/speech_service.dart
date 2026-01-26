import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechInitResult {
  final bool ready;
  final String? errorMessage;
  final List<stt.LocaleName> locales;

  const SpeechInitResult({
    required this.ready,
    this.errorMessage,
    this.locales = const [],
  });
}

abstract class SpeechServiceBase {
  List<stt.LocaleName> get locales;
  bool get isListening;
  Future<SpeechInitResult> initialize({
    required void Function(SpeechRecognitionError) onError,
    required void Function(String) onStatus,
    bool requestPermission = true,
  });
  Future<void> listen({
    required void Function(SpeechRecognitionResult) onResult,
    required void Function(double) onSoundLevelChange,
    required Duration listenFor,
    required Duration pauseFor,
    String? localeId,
    required stt.ListenMode listenMode,
    bool partialResults,
  });
  Future<void> stop();
  void dispose();
}

class SpeechService implements SpeechServiceBase {
  SpeechService({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  List<stt.LocaleName> _locales = const [];
  void Function(SpeechRecognitionError error)? _errorSink;
  void Function(String status)? _statusSink;
  Future<SpeechInitResult>? _initFuture;
  bool _initialized = false;

  @override
  List<stt.LocaleName> get locales => _locales;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<SpeechInitResult> initialize({
    required void Function(SpeechRecognitionError) onError,
    required void Function(String) onStatus,
    bool requestPermission = true,
  }) async {
    _errorSink = onError;
    _statusSink = onStatus;
    final micStatus = requestPermission
        ? await Permission.microphone.request()
        : await Permission.microphone.status;
    if (!micStatus.isGranted) {
      return const SpeechInitResult(
        ready: false,
        errorMessage:
            'Microphone permission is required. Enable it in system settings.',
      );
    }

    if (_initialized) {
      return SpeechInitResult(ready: true, locales: _locales);
    }

    _initFuture ??= _initializeSpeech();
    final result = await _initFuture!;
    if (result.ready) {
      _initialized = true;
    } else {
      _initFuture = null;
    }
    return result;
  }

  @override
  Future<void> listen({
    required void Function(SpeechRecognitionResult) onResult,
    required void Function(double) onSoundLevelChange,
    required Duration listenFor,
    required Duration pauseFor,
    String? localeId,
    required stt.ListenMode listenMode,
    bool partialResults = true,
  }) async {
    await _speech.listen(
      onResult: onResult,
      onSoundLevelChange: onSoundLevelChange,
      listenFor: listenFor,
      pauseFor: pauseFor,
      localeId: localeId,
      listenOptions: stt.SpeechListenOptions(
        listenMode: listenMode,
        partialResults: partialResults,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
  }

  @override
  void dispose() {
    _errorSink = null;
    _statusSink = null;
    unawaited(_speech.stop());
  }

  Future<SpeechInitResult> _initializeSpeech() async {
    final available = await _speech.initialize(
      onError: _handleError,
      onStatus: _handleStatus,
    );

    if (!available) {
      return const SpeechInitResult(
        ready: false,
        errorMessage: 'Speech recognition is not available on this device.',
      );
    }

    _locales = await _speech.locales();
    return SpeechInitResult(ready: true, locales: _locales);
  }

  void _handleError(SpeechRecognitionError error) {
    _errorSink?.call(error);
  }

  void _handleStatus(String status) {
    _statusSink?.call(status);
  }
}
