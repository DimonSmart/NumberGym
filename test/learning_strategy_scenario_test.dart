import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_params.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_queue.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_strategy.dart';
import 'package:number_gym/features/training/domain/training_item.dart';

void main() {
  test('learned card is removed from active and replaced from backlog', () {
    const params = LearningParams(
      activeLimit: 2,
      clusterSuccessAccuracy: 0.8,
      clusterMaxGapMinutes: 30,
      maxStoredClusters: 10,
      minDaysBetweenCountedSuccesses: 0,
      minSpacedSuccessClusters: 1,
      learnedIntervalDays: 1,
      easeUpOnSuccess: 0.0,
      easeDownOnFail: 0.0,
      failIntervalFactor: 1.0,
      minIntervalDays: 1,
      maxIntervalDays: 10,
      easeMin: 1.0,
      easeMax: 2.0,
      initialEase: 1.0,
      initialIntervalDays: 1.0,
    );

    final ids = <TrainingItemId>[
      const TrainingItemId(type: TrainingItemType.digits, number: 0),
      const TrainingItemId(type: TrainingItemType.digits, number: 1),
      const TrainingItemId(type: TrainingItemType.digits, number: 2),
    ];

    final queue = LearningQueue(allCards: ids, activeLimit: 2);
    queue.reset(unlearned: ids);

    final strategy = LearningStrategy.defaults(queue: queue, params: params);

    final result = strategy.applyClusterResult(
      itemId: ids[0],
      progress: CardProgress.empty,
      accuracy: 1.0,
      now: DateTime(2026, 1, 1, 12, 0),
    );

    expect(result.learnedNow, isTrue);
    expect(queue.active, [ids[1], ids[2]]);
    expect(queue.backlog, isEmpty);
  });
}
