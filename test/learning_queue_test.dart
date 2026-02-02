import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_queue.dart';
import 'package:number_gym/features/training/domain/training_item.dart';

void main() {
  test('fills active window from backlog and refills after removal', () {
    final ids = <TrainingItemId>[
      const TrainingItemId(type: TrainingItemType.digits, number: 0),
      const TrainingItemId(type: TrainingItemType.digits, number: 1),
      const TrainingItemId(type: TrainingItemType.digits, number: 2),
      const TrainingItemId(type: TrainingItemType.digits, number: 3),
    ];
    final queue = LearningQueue(allCards: ids, activeLimit: 2);

    queue.reset(unlearned: ids);

    expect(queue.active, [ids[0], ids[1]]);
    expect(queue.backlog, [ids[2], ids[3]]);

    final removed = queue.removeFromActive(ids[0]);
    expect(removed, isTrue);

    queue.fillActive();

    expect(queue.active, [ids[1], ids[2]]);
    expect(queue.backlog, [ids[3]]);
  });
}
