import 'task_state.dart';
import 'training_item.dart';

class TrainingCelebrationFormatter {
  const TrainingCelebrationFormatter();

  static final RegExp _clockValuePattern = RegExp(r'^\d{1,2}:\d{2}$');

  String masteredText(TaskState taskState) {
    final numberValue = taskState.numberValue ?? taskState.taskId.number;
    if (numberValue != null) {
      return numberValue.toString();
    }

    final taskTime = taskState.taskId.time;
    if (taskTime != null) {
      return taskTime.displayText;
    }
    if (taskState is ListeningState && taskState.timeValue != null) {
      return taskState.timeValue!.displayText;
    }

    final text = taskState.displayText.trim();
    if (_clockValuePattern.hasMatch(text)) {
      return text;
    }
    return '';
  }

  String categoryLabel(TrainingItemType type) {
    switch (type) {
      case TrainingItemType.digits:
        return 'Single digits';
      case TrainingItemType.base:
        return 'Base numbers';
      case TrainingItemType.hundreds:
        return 'Hundreds';
      case TrainingItemType.thousands:
        return 'Thousands';
      case TrainingItemType.timeExact:
        return 'Exact time';
      case TrainingItemType.timeQuarter:
        return 'Quarter-hour time';
      case TrainingItemType.timeHalf:
        return 'Half-hour time';
      case TrainingItemType.timeRandom:
        return 'Random time';
      case TrainingItemType.phone33x3:
        return 'Phone numbers (3-3-3)';
      case TrainingItemType.phone3222:
        return 'Phone numbers (3-2-2-2)';
      case TrainingItemType.phone2322:
        return 'Phone numbers (2-3-2-2)';
    }
  }
}
