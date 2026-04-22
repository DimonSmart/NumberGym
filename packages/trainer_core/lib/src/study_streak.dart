import 'day_key.dart';

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
    for (final entry in rawValue.split(',')) {
      if (entry.trim().isEmpty) {
        continue;
      }
      final pair = entry.split(':');
      if (pair.length != 2) {
        continue;
      }
      final dayKey = pair[0].trim();
      if (parseDayKey(dayKey) == null) {
        continue;
      }
      final sessions = int.tryParse(pair[1].trim());
      if (sessions == null || sessions <= 0) {
        continue;
      }
      parsed[dayKey] = sessions;
    }
    return StudyStreak(sessionsByDay: parsed);
  }

  String toStorage() {
    if (sessionsByDay.isEmpty) {
      return '';
    }
    final sorted = sessionsByDay.keys.toList()..sort();
    return sorted.map((key) => '$key:${sessionsByDay[key]}').join(',');
  }

  int sessionsOn(DateTime date) => sessionsByDay[formatDayKey(date)] ?? 0;

  bool hasActivityOn(DateTime date) => sessionsOn(date) > 0;

  StudyStreak addCompletedSession({
    required DateTime now,
    int retentionDays = defaultRetentionDays,
  }) {
    final normalizedDay = _startOfDay(now.toLocal());
    return setSessionsForDay(
      day: normalizedDay,
      sessionsCompleted: sessionsOn(normalizedDay) + 1,
      retentionDays: retentionDays,
    );
  }

  StudyStreak setSessionsForDay({
    required DateTime day,
    required int sessionsCompleted,
    int retentionDays = defaultRetentionDays,
  }) {
    final normalizedDay = _startOfDay(day.toLocal());
    final cutoff = normalizedDay.subtract(
      Duration(days: (retentionDays < 1 ? 1 : retentionDays) - 1),
    );
    final updated = Map<String, int>.from(sessionsByDay);
    final dayKey = formatDayKey(normalizedDay);
    if (sessionsCompleted <= 0) {
      updated.remove(dayKey);
    } else {
      updated[dayKey] = sessionsCompleted;
    }
    updated.removeWhere((storedKey, sessions) {
      if (sessions <= 0) {
        return true;
      }
      final parsed = parseDayKey(storedKey);
      if (parsed == null) {
        return true;
      }
      return parsed.isBefore(cutoff);
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

  static DateTime? parseDayKey(String dayKey) {
    if (!_dayKeyPattern.hasMatch(dayKey)) {
      return null;
    }
    final year = int.tryParse(dayKey.substring(0, 4));
    final month = int.tryParse(dayKey.substring(5, 7));
    final day = int.tryParse(dayKey.substring(8, 10));
    if (year == null || month == null || day == null) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static Map<String, int> _normalizeEntries(Map<String, int> entries) {
    final normalized = <String, int>{};
    for (final entry in entries.entries) {
      final parsed = parseDayKey(entry.key);
      if (parsed == null || entry.value <= 0) {
        continue;
      }
      normalized[formatDayKey(parsed)] = entry.value;
    }
    return normalized;
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
