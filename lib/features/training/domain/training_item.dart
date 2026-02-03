import 'time_value.dart';

enum TrainingItemType {
  digits,
  base,
  hundreds,
  thousands,
  timeExact,
  timeQuarter,
  timeHalf,
  timeRandom,
}

class TrainingItemId implements Comparable<TrainingItemId> {
  const TrainingItemId({
    required this.type,
    this.number,
    this.time,
  });

  final TrainingItemType type;
  final int? number;
  final TimeValue? time;

  String get storageKey {
    final suffix = time?.storageKey ?? number?.toString() ?? '*';
    return '${type.name}:$suffix';
  }

  @override
  String toString() => storageKey;

  @override
  bool operator ==(Object other) {
    return other is TrainingItemId &&
        other.type == type &&
        other.number == number &&
        other.time == time;
  }

  @override
  int get hashCode => Object.hash(type, number, time);

  @override
  int compareTo(TrainingItemId other) {
    final typeCompare = type.index.compareTo(other.type.index);
    if (typeCompare != 0) return typeCompare;
    if (time != null || other.time != null) {
      final left = time ?? const TimeValue(hour: -1, minute: -1);
      final right = other.time ?? const TimeValue(hour: -1, minute: -1);
      return left.compareTo(right);
    }
    final left = number ?? -1;
    final right = other.number ?? -1;
    return left.compareTo(right);
  }
}
