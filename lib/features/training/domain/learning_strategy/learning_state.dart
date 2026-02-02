import '../../data/card_progress.dart';
import '../training_item.dart';

class LearningState {
  final TrainingItemId id;
  final CardProgress progress;

  const LearningState({
    required this.id,
    required this.progress,
  });

  int get nextDueMillis => progress.nextDue;
  double get intervalDays => progress.intervalDays;
  double get ease => progress.ease;
  int get spacedSuccessCount => progress.spacedSuccessCount;
  int get lastCountedSuccessDay => progress.lastCountedSuccessDay;

  bool isDue(DateTime now) {
    return progress.nextDue <= now.millisecondsSinceEpoch;
  }
}
