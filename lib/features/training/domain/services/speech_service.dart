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

  @override
  List<stt.LocaleName> get locales => _locales;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<SpeechInitResult> initialize({
    required void Function(SpeechRecognitionError) onError,
    required void Function(String) onStatus,
  }) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return const SpeechInitResult(
        ready: false,
        errorMessage:
            'Microphone permission is required. Enable it in system settings.',
      );
    }

    final available = await _speech.initialize(
      onError: onError,
      onStatus: onStatus,
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
    unawaited(_speech.stop());
  }
}
