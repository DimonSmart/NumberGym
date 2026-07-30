import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  test('runs commands in order and recovers after an error', () async {
    final queue = SerializedOperationQueue();
    final calls = <String>[];
    final gate = Completer<void>();

    final first = queue.enqueue(() async {
      calls.add('first-start');
      await gate.future;
      calls.add('first-end');
    });
    final failed = queue.enqueue<void>(() async {
      calls.add('failed');
      throw StateError('expected');
    });
    final third = queue.enqueue(() async => calls.add('third'));

    await Future<void>.delayed(Duration.zero);
    expect(calls, ['first-start']);
    gate.complete();
    await first;
    await expectLater(failed, throwsStateError);
    await third;
    expect(calls, ['first-start', 'first-end', 'failed', 'third']);
  });

  test('does not accept commands after close', () async {
    final queue = SerializedOperationQueue();
    await queue.close();
    await expectLater(queue.enqueue(() async {}), throwsStateError);
  });

  test('close waits for queued work and is idempotent', () async {
    final queue = SerializedOperationQueue();
    final gate = Completer<void>();
    final calls = <String>[];
    final first = queue.enqueue(() async {
      calls.add('first');
      await gate.future;
    });
    final second = queue.enqueue(() async => calls.add('second'));

    final close = queue.close();
    var closeCompleted = false;
    close.whenComplete(() => closeCompleted = true);
    expect(identical(close, queue.close()), isTrue);
    expect(closeCompleted, isFalse);
    await expectLater(queue.enqueue(() async {}), throwsStateError);

    gate.complete();
    await Future.wait([first, second, close]);
    expect(calls, ['first', 'second']);
  });

  test('preserves generic results and independent consecutive errors', () async {
    final queue = SerializedOperationQueue();
    final first = queue.enqueue<int>(() async => throw StateError('first'));
    final second = queue.enqueue<int>(() async => throw ArgumentError('second'));
    final third = queue.enqueue(() async => 42);

    await expectLater(first, throwsStateError);
    await expectLater(second, throwsArgumentError);
    expect(await third, 42);
  });
}
