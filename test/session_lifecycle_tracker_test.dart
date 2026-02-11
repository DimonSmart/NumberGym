import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/session_lifecycle_tracker.dart';

void main() {
  test('reset normalizes target and clears counters', () {
    final tracker = SessionLifecycleTracker();
    tracker.reset(targetCards: -5, now: DateTime(2026, 2, 10, 9, 0));
    tracker.incrementCompleted();
    tracker.markStatsPersisted();

    tracker.reset(targetCards: -1, now: DateTime(2026, 2, 10, 10, 0));

    expect(tracker.targetCards, 0);
    expect(tracker.cardsCompleted, 0);
    expect(tracker.statsPersisted, isFalse);
  });

  test('tracks completion and safe elapsed duration', () {
    final tracker = SessionLifecycleTracker();
    final startedAt = DateTime(2026, 2, 10, 10, 0);
    tracker.reset(targetCards: 2, now: startedAt);
    tracker.incrementCompleted();

    expect(tracker.reachedLimit, isFalse);
    expect(
      tracker.elapsed(now: startedAt.add(const Duration(minutes: 3))),
      const Duration(minutes: 3),
    );
    expect(
      tracker.elapsed(now: startedAt.subtract(const Duration(seconds: 1))),
      Duration.zero,
    );

    tracker.incrementCompleted();
    expect(tracker.reachedLimit, isTrue);
  });

  test('celebration target falls back to cards completed', () {
    final tracker = SessionLifecycleTracker();
    tracker.reset(targetCards: 0, now: DateTime(2026, 2, 10, 12, 0));
    expect(tracker.celebrationTargetCards(), 1);

    tracker.incrementCompleted();
    tracker.incrementCompleted();
    expect(tracker.celebrationTargetCards(), 2);
  });
}
