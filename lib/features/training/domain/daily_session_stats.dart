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
  bool get hasSessions => sessionsCompleted > 0;

  factory DailySessionStats.emptyFor(DateTime now) {
    return DailySessionStats(
      dayKey: dayKeyFor(now),
      sessionsCompleted: 0,
      cardsCompleted: 0,
      durationSeconds: 0,
    );
  }

  DailySessionStats normalizedFor(DateTime now) {
    if (dayKey == dayKeyFor(now)) {
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
    final normalizedCards = cards < 0 ? 0 : cards;
    final normalizedSeconds = sessionDuration.inSeconds < 0
        ? 0
        : sessionDuration.inSeconds;
    return DailySessionStats(
      dayKey: dayKeyFor(now),
      sessionsCompleted: base.sessionsCompleted + 1,
      cardsCompleted: base.cardsCompleted + normalizedCards,
      durationSeconds: base.durationSeconds + normalizedSeconds,
    );
  }

  static String dayKeyFor(DateTime now) {
    final local = now.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
