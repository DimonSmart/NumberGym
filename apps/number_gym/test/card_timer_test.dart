import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/services/card_timer.dart';

void main() {
  test('pause and resume keep remaining time', () async {
    var timedOut = false;
    final timer = CardTimer();

    timer.start(const Duration(milliseconds: 300), () {
      timedOut = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));
    timer.pause();
    final pausedRemaining = timer.remaining();

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(timedOut, isFalse);
    final stillPausedRemaining = timer.remaining();
    final pausedDrift = (stillPausedRemaining - pausedRemaining).inMilliseconds
        .abs();
    expect(pausedDrift, lessThan(40));

    timer.resume();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(timedOut, isTrue);
    expect(timer.remaining(), Duration.zero);
  });
}
