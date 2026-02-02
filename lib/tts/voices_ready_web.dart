import 'dart:async';
import 'dart:html' as html;

class VoicesReady {
  StreamSubscription<html.Event>? _sub;

  Future<void> wait({Duration timeout = const Duration(seconds: 2)}) async {
    final synth = html.window.speechSynthesis;
    if (synth == null) return;

    // Some browsers only populate voices after the first getVoices().
    synth.getVoices();

    if (synth.getVoices().isNotEmpty) return;

    final completer = Completer<void>();

    void tryComplete() {
      if (!completer.isCompleted && synth.getVoices().isNotEmpty) {
        completer.complete();
      }
    }

    _sub ??= html.EventStreamProvider<html.Event>('voiceschanged')
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
}
