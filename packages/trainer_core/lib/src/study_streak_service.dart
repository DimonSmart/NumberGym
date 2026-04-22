import 'trainer_repositories.dart';

class StudyStreakDaySnapshot {
  const StudyStreakDaySnapshot({
    required this.day,
    required this.sessionsCompleted,
  });

  final DateTime day;
  final int sessionsCompleted;

  bool get hasActivity => sessionsCompleted > 0;
}

class StudyStreakSnapshot {
  StudyStreakSnapshot({
    required this.currentStreakDays,
    required this.today,
    required this.monthStart,
    required this.firstWeekdayOffset,
    required List<StudyStreakDaySnapshot> monthDays,
  }) : monthDays = List<StudyStreakDaySnapshot>.unmodifiable(monthDays);

  final int currentStreakDays;
  final DateTime today;
  final DateTime monthStart;
  final int firstWeekdayOffset;
  final List<StudyStreakDaySnapshot> monthDays;
}

class StudyStreakService {
  StudyStreakService({required SettingsRepositoryBase settingsRepository})
    : _settingsRepository = settingsRepository;

  final SettingsRepositoryBase _settingsRepository;

  StudyStreakSnapshot readCurrentStreakSnapshot({DateTime? now}) {
    final resolvedNow = (now ?? DateTime.now()).toLocal();
    final today = DateTime(
      resolvedNow.year,
      resolvedNow.month,
      resolvedNow.day,
    );
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0);
    final streak = _readNormalizedStreak(today);
    final days = List<StudyStreakDaySnapshot>.generate(monthEnd.day, (index) {
      final day = monthStart.add(Duration(days: index));
      return StudyStreakDaySnapshot(
        day: day,
        sessionsCompleted: streak.sessionsOn(day),
      );
    });
    return StudyStreakSnapshot(
      currentStreakDays: streak.currentStreakDays(now: today),
      today: today,
      monthStart: monthStart,
      firstWeekdayOffset: monthStart.weekday - 1,
      monthDays: days,
    );
  }

  Future<StudyStreak> recordCompletedSession({DateTime? now}) async {
    final resolvedNow = (now ?? DateTime.now()).toLocal();
    final day = DateTime(resolvedNow.year, resolvedNow.month, resolvedNow.day);
    final dailyStats = _settingsRepository.readDailySessionStats(now: day);
    var updated = _readNormalizedStreak(day);
    if (dailyStats.sessionsCompleted <= 0) {
      updated = updated.addCompletedSession(now: day);
    }
    await _settingsRepository.setStudyStreak(updated);
    return updated;
  }

  StudyStreak _readNormalizedStreak(DateTime day) {
    final streak = _settingsRepository.readStudyStreak();
    final dailyStats = _settingsRepository.readDailySessionStats(now: day);
    final sessionsToday = dailyStats.sessionsCompleted < 0
        ? 0
        : dailyStats.sessionsCompleted;
    if (sessionsToday <= streak.sessionsOn(day)) {
      return streak;
    }
    return streak.setSessionsForDay(day: day, sessionsCompleted: sessionsToday);
  }
}
