import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/logging/app_logger.dart';

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
  Future<void> cancel();
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
  Future<void>? _pendingCleanup;
  bool _initialized = false;

  static const Duration _cleanupWaitTimeout = Duration(milliseconds: 500);

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
    await _waitForPendingCleanupBeforeListen();
    final startedAt = DateTime.now();
    appLogD(
      'speech',
      'recognizer listen start locale="${localeId ?? ''}" '
          'mode=${listenMode.name} listenFor=${listenFor.inMilliseconds}ms '
          'pauseFor=${pauseFor.inMilliseconds}ms',
    );
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
    appLogD(
      'speech',
      'recognizer listen returned duration=${_formatDuration(DateTime.now().difference(startedAt))}',
    );
  }

  @override
  Future<void> stop() async {
    await _runCleanup('stop', _speech.stop);
  }

  @override
  Future<void> cancel() async {
    await _runCleanup('cancel', _speech.cancel);
  }

  @override
  void dispose() {
    _errorSink = null;
    _statusSink = null;
    unawaited(
      _runCleanup('dispose-stop', _speech.stop).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        appLogW(
          'speech',
          'recognizer dispose stop failed',
          error: error,
          st: stackTrace,
        );
      }),
    );
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

  Future<void> _waitForPendingCleanupBeforeListen() async {
    final cleanup = _pendingCleanup;
    if (cleanup == null) {
      return;
    }
    final startedAt = DateTime.now();
    appLogD('speech', 'waiting for pending recognizer cleanup before listen');
    try {
      await cleanup.timeout(_cleanupWaitTimeout);
      appLogD(
        'speech',
        'pending recognizer cleanup completed before listen '
            'wait=${_formatDuration(DateTime.now().difference(startedAt))}',
      );
    } on TimeoutException {
      if (identical(_pendingCleanup, cleanup)) {
        _pendingCleanup = null;
      }
      appLogW(
        'speech',
        'pending recognizer cleanup still running after '
            '${_formatDuration(_cleanupWaitTimeout)}; starting listen anyway',
      );
    } catch (error, stackTrace) {
      appLogW(
        'speech',
        'pending recognizer cleanup failed before listen',
        error: error,
        st: stackTrace,
      );
    }
  }

  Future<void> _runCleanup(String operation, Future<void> Function() cleanup) {
    final existing = _pendingCleanup;
    if (existing != null) {
      appLogD('speech', 'recognizer $operation joined pending cleanup');
      return existing;
    }
    final startedAt = DateTime.now();
    appLogD('speech', 'recognizer $operation start');
    late final Future<void> pending;
    pending = cleanup().whenComplete(() {
      final elapsed = DateTime.now().difference(startedAt);
      appLogD(
        'speech',
        'recognizer $operation finished duration=${_formatDuration(elapsed)}',
      );
      if (identical(_pendingCleanup, pending)) {
        _pendingCleanup = null;
      }
    });
    _pendingCleanup = pending;
    return pending;
  }

  String _formatDuration(Duration duration) {
    return '${duration.inMilliseconds}ms';
  }
}
