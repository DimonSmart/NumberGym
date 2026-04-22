class TimeValue implements Comparable<TimeValue> {
  const TimeValue({
    required this.hour,
    required this.minute,
  }) : assert(hour >= 0 && hour <= 23),
       assert(minute >= 0 && minute <= 59);

  final int hour;
  final int minute;

  String get displayText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get storageKey => displayText;

  @override
  int compareTo(TimeValue other) {
    final hourCompare = hour.compareTo(other.hour);
    if (hourCompare != 0) return hourCompare;
    return minute.compareTo(other.minute);
  }

  @override
  bool operator ==(Object other) {
    return other is TimeValue && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);
}
