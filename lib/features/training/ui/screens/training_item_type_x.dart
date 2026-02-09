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
}
