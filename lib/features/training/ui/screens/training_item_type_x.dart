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
    TrainingItemType.phone33x3 => 'Phone numbers (3-3-3)',
    TrainingItemType.phone3222 => 'Phone numbers (3-2-2-2)',
    TrainingItemType.phone2322 => 'Phone numbers (2-3-2-2)',
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
    TrainingItemType.phone33x3 => '(+34) XXX XXX XXX',
    TrainingItemType.phone3222 => '(+34) XXX XX XX XX',
    TrainingItemType.phone2322 => '(+34) XX XXX XX XX',
  };
}
