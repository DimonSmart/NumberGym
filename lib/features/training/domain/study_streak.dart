class StudyStreak {
  StudyStreak({required Map<String, int> sessionsByDay})
    : sessionsByDay = Map.unmodifiable(_normalizeEntries(sessionsByDay));

  final Map<String, int> sessionsByDay;

  static const int defaultRetentionDays = 540;
  static final RegExp _dayKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  factory StudyStreak.empty() {
    return StudyStreak(sessionsByDay: const <String, int>{});
  }

  factory StudyStreak.fromStorage(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return StudyStreak.empty();
    }

    final parsed = <String, int>{};
    final entries = rawValue.split(',');
    for (final entry in entries) {
      if (entry.trim().isEmpty) continue;
      final pair = entry.split(':');
      if (pair.length != 2) continue;

      final dayKey = pair[0].trim();
      if (parseDayKey(dayKey) == null) continue;

      final sessions = int.tryParse(pair[1].trim());
      if (sessions == null || sessions <= 0) continue;
      parsed[dayKey] = sessions;
    }

    return StudyStreak(sessionsByDay: parsed);
  }

  String toStorage() {
    if (sessionsByDay.isEmpty) return '';
    final sortedKeys = sessionsByDay.keys.toList()..sort();
    return sortedKeys
        .map((dayKey) => '$dayKey:${sessionsByDay[dayKey]}')
        .join(',');
  }

  int sessionsOn(DateTime date) {
    return sessionsByDay[dayKeyFor(date)] ?? 0;
  }

  bool hasActivityOn(DateTime date) {
    return sessionsOn(date) > 0;
  }

  DateTime? latestActivityDay() {
    DateTime? latest;
    for (final dayKey in sessionsByDay.keys) {
      final day = parseDayKey(dayKey);
      if (day == null) continue;
      if (latest == null || day.isAfter(latest)) {
        latest = day;
      }
    }
    return latest;
  }

  StudyStreak addCompletedSession({
    required DateTime now,
    int retentionDays = defaultRetentionDays,
  }) {
    final normalizedDay = _startOfDay(now.toLocal());
    final nextSessions = sessionsOn(normalizedDay) + 1;
    return setSessionsForDay(
      day: normalizedDay,
      sessionsCompleted: nextSessions,
      retentionDays: retentionDays,
    );
  }

  StudyStreak setSessionsForDay({
    required DateTime day,
    required int sessionsCompleted,
    int retentionDays = defaultRetentionDays,
  }) {
    final normalizedDay = _startOfDay(day.toLocal());
    final normalizedRetention = retentionDays < 1 ? 1 : retentionDays;
    final cutoff = normalizedDay.subtract(
      Duration(days: normalizedRetention - 1),
    );
    final dayKey = StudyStreak.dayKeyFor(normalizedDay);

    final updated = Map<String, int>.from(sessionsByDay);
    if (sessionsCompleted <= 0) {
      updated.remove(dayKey);
    } else {
      updated[dayKey] = sessionsCompleted;
    }

    updated.removeWhere((storedDayKey, sessions) {
      if (sessions <= 0) return true;
      final parsedDay = parseDayKey(storedDayKey);
      if (parsedDay == null) return true;
      return parsedDay.isBefore(cutoff);
    });

    return StudyStreak(sessionsByDay: updated);
  }

  int currentStreakDays({DateTime? now}) {
    final resolvedNow = _startOfDay((now ?? DateTime.now()).toLocal());
    if (hasActivityOn(resolvedNow)) {
      return _countConsecutiveBackwards(from: resolvedNow);
    }

    final yesterday = resolvedNow.subtract(const Duration(days: 1));
    if (hasActivityOn(yesterday)) {
      return _countConsecutiveBackwards(from: yesterday);
    }

    return 0;
  }

  int _countConsecutiveBackwards({required DateTime from}) {
    var count = 0;
    var cursor = from;
    while (hasActivityOn(cursor)) {
      count += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static String dayKeyFor(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime? parseDayKey(String dayKey) {
    if (!_dayKeyPattern.hasMatch(dayKey)) return null;
    final year = int.tryParse(dayKey.substring(0, 4));
    final month = int.tryParse(dayKey.substring(5, 7));
    final day = int.tryParse(dayKey.substring(8, 10));
    if (year == null || month == null || day == null) return null;

    final parsed = DateTime(year, month, day);
    final valid =
        parsed.year == year && parsed.month == month && parsed.day == day;
    if (!valid) return null;
    return parsed;
  }

  static Map<String, int> _normalizeEntries(Map<String, int> entries) {
    final normalized = <String, int>{};
    for (final entry in entries.entries) {
      final day = parseDayKey(entry.key);
      if (day == null) continue;
      final sessions = entry.value;
      if (sessions <= 0) continue;
      normalized[dayKeyFor(day)] = sessions;
    }
    return normalized;
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
