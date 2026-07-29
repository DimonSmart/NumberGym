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
}
