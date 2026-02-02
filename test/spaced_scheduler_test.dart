import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_params.dart';
import 'package:number_gym/features/training/domain/learning_strategy/spaced_scheduler.dart';

void main() {
  const params = LearningParams(
    activeLimit: 2,
    clusterSuccessAccuracy: 0.8,
    clusterMaxGapMinutes: 30,
    maxStoredClusters: 10,
    minDaysBetweenCountedSuccesses: 2,
    minSpacedSuccessClusters: 2,
    learnedIntervalDays: 5,
    easeUpOnSuccess: 0.1,
    easeDownOnFail: 0.2,
    failIntervalFactor: 0.5,
    minIntervalDays: 1,
    maxIntervalDays: 30,
    easeMin: 1.0,
    easeMax: 3.0,
    initialEase: 2.0,
    initialIntervalDays: 2.0,
  );

  test('success increases interval and ease and counts spaced success', () {
    const progress = CardProgress.empty;
    final scheduler = SpacedScheduler(params);
    final now = DateTime(2026, 1, 1, 10, 0);

    final result = scheduler.applyClusterResult(
      progress: progress,
      accuracy: 1.0,
      now: now,
    );

    expect(result.clusterSuccess, isTrue);
    expect(result.countedSuccess, isTrue);
    expect(result.progress.ease, closeTo(2.1, 0.0001));
    expect(result.progress.intervalDays, closeTo(4.2, 0.0001));
    expect(result.progress.spacedSuccessCount, 1);

    final repeat = scheduler.applyClusterResult(
      progress: result.progress,
      accuracy: 1.0,
      now: now,
    );
    expect(repeat.progress.spacedSuccessCount, 1);
    expect(repeat.countedSuccess, isFalse);
  });

  test('fail lowers ease and interval but respects min interval', () {
    const progress = CardProgress(
      learned: false,
      clusters: <CardCluster>[],
      intervalDays: 4,
      nextDue: 0,
      ease: 2.0,
      spacedSuccessCount: 0,
      lastCountedSuccessDay: -1,
      learnedAt: 0,
    );
    final scheduler = SpacedScheduler(params);
    final result = scheduler.applyClusterResult(
      progress: progress,
      accuracy: 0.2,
      now: DateTime(2026, 1, 2, 9, 0),
    );

    expect(result.clusterSuccess, isFalse);
    expect(result.progress.ease, closeTo(1.8, 0.0001));
    expect(result.progress.intervalDays, closeTo(2.0, 0.0001));
  });

  test('learned requires spaced successes and interval threshold', () {
    const progress = CardProgress(
      learned: false,
      clusters: <CardCluster>[],
      intervalDays: 4,
      nextDue: 0,
      ease: 2.0,
      spacedSuccessCount: 1,
      lastCountedSuccessDay: -1,
      learnedAt: 0,
    );
    final scheduler = SpacedScheduler(params);
    final now = DateTime(2026, 1, 4, 9, 0);

    final result = scheduler.applyClusterResult(
      progress: progress,
      accuracy: 1.0,
      now: now,
    );

    expect(result.progress.spacedSuccessCount, 2);
    expect(result.progress.intervalDays >= 5, isTrue);
    expect(result.progress.learned, isTrue);
  });
}
