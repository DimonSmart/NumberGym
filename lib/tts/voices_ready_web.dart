import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class VoicesReady {
  StreamSubscription<web.Event>? _sub;

  Future<void> wait({Duration timeout = const Duration(seconds: 2)}) async {
    final synth = web.window.speechSynthesis;

    // Some browsers only populate voices after the first getVoices().
    final initialVoices = _hasVoices(synth);
    if (initialVoices == null) return;
    if (initialVoices) return;

    final completer = Completer<void>();

    void tryComplete() {
      if (!completer.isCompleted && _hasVoices(synth) == true) {
        completer.complete();
      }
    }

    _sub ??= web.EventStreamProvider<web.Event>('voiceschanged')
        .forTarget(synth)
        .listen((_) {
      // Let the browser apply updates before checking.
      scheduleMicrotask(tryComplete);
    });

    final deadline = DateTime.now().add(timeout);
    while (!completer.isCompleted && DateTime.now().isBefore(deadline)) {
      tryComplete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!completer.isCompleted) {
      completer.complete();
    }

    await completer.future;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  bool? _hasVoices(web.SpeechSynthesis synth) {
    try {
      return synth.getVoices().toDart.isNotEmpty;
    } catch (_) {
      return null;
    }
  }
}
