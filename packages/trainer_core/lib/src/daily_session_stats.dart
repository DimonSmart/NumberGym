import 'day_key.dart';

class DailySessionStats {
  const DailySessionStats({
    required this.dayKey,
    required this.sessionsCompleted,
    required this.cardsCompleted,
    required this.durationSeconds,
  });

  final String dayKey;
  final int sessionsCompleted;
  final int cardsCompleted;
  final int durationSeconds;

  Duration get duration => Duration(seconds: durationSeconds);

  factory DailySessionStats.emptyFor(DateTime now) {
    return DailySessionStats(
      dayKey: formatDayKey(now),
      sessionsCompleted: 0,
      cardsCompleted: 0,
      durationSeconds: 0,
    );
  }

  DailySessionStats normalizedFor(DateTime now) {
    if (dayKey == formatDayKey(now)) {
      return this;
    }
    return DailySessionStats.emptyFor(now);
  }

  DailySessionStats addSession({
    required int cards,
    required Duration sessionDuration,
    required DateTime now,
  }) {
    final base = normalizedFor(now);
    return DailySessionStats(
      dayKey: formatDayKey(now),
      sessionsCompleted: base.sessionsCompleted + 1,
      cardsCompleted: base.cardsCompleted + (cards < 0 ? 0 : cards),
      durationSeconds:
          base.durationSeconds +
          (sessionDuration.inSeconds < 0 ? 0 : sessionDuration.inSeconds),
    );
  }
}
