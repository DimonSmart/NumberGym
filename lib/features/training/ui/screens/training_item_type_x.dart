import '../../domain/training_item.dart';

extension TrainingItemTypeX on TrainingItemType {
  String get label => switch (this) {
        TrainingItemType.digits => 'Digits',
        TrainingItemType.base => 'Base',
        TrainingItemType.hundreds => 'Hundreds',
        TrainingItemType.thousands => 'Thousands',
        TrainingItemType.timeExact => 'Time (exact)',
        TrainingItemType.timeQuarter => 'Time (quarter)',
        TrainingItemType.timeHalf => 'Time (half)',
        TrainingItemType.timeRandom => 'Time (random)',
      };

  String get range => switch (this) {
        TrainingItemType.digits => '(0-9)',
        TrainingItemType.base => '(10-99)',
        TrainingItemType.hundreds => '(100-900)',
        TrainingItemType.thousands => '(1000-9000)',
        TrainingItemType.timeExact => '(HH:00)',
        TrainingItemType.timeQuarter => '(HH:15, HH:45)',
        TrainingItemType.timeHalf => '(HH:30)',
        TrainingItemType.timeRandom => '(HH:MM)',
      };

  bool get supportsStreak => this != TrainingItemType.timeRandom;

  int preferredColumns(int count) {
    final safeCount = count <= 0 ? 1 : count;
    final preferred = switch (this) {
          TrainingItemType.digits => 10,
          TrainingItemType.base => 10,
          TrainingItemType.hundreds => 9,
          TrainingItemType.thousands => 5,
          TrainingItemType.timeExact => 8,
          TrainingItemType.timeQuarter => 8,
          TrainingItemType.timeHalf => 8,
          TrainingItemType.timeRandom => 1,
        };
    return preferred > safeCount ? safeCount : preferred;
  }
}
