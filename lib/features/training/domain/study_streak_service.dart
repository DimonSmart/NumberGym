import 'repositories.dart';
import 'study_streak.dart';

class StudyStreakDaySnapshot {
  const StudyStreakDaySnapshot({
    required this.day,
    required this.sessionsCompleted,
  });

  final DateTime day;
  final int sessionsCompleted;

  bool get hasActivity => sessionsCompleted > 0;
  bool get hasMultipleSessions => sessionsCompleted > 1;
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

  int get activeDaysInMonth {
    return monthDays.where((day) => day.hasActivity).length;
  }
}

abstract interface class StreakStatusProvider {
  int readCurrentStreakDays({DateTime? now});
}

abstract interface class StudyStreakSnapshotProvider {
  StudyStreakSnapshot readCurrentStreakSnapshot({DateTime? now});
}

class StudyStreakService
    implements StreakStatusProvider, StudyStreakSnapshotProvider {
  StudyStreakService({required SettingsRepositoryBase settingsRepository})
    : _settingsRepository = settingsRepository;

  final SettingsRepositoryBase _settingsRepository;

  @override
  int readCurrentStreakDays({DateTime? now}) {
    final resolvedNow = (now ?? DateTime.now()).toLocal();
    final day = DateTime(resolvedNow.year, resolvedNow.month, resolvedNow.day);
    final streak = _readNormalizedStreak(day);
    return streak.currentStreakDays(now: day);
  }

  @override
  StudyStreakSnapshot readCurrentStreakSnapshot({DateTime? now}) {
    final resolvedNow = (now ?? DateTime.now()).toLocal();
    final today = DateTime(
      resolvedNow.year,
      resolvedNow.month,
      resolvedNow.day,
    );
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0);
    final daysInMonth = monthEnd.day;

    final streak = _readNormalizedStreak(today);
    final days = List<StudyStreakDaySnapshot>.generate(daysInMonth, (index) {
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
