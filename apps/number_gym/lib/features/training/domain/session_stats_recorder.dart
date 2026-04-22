import 'daily_session_stats.dart';
import 'repositories.dart';
import 'study_streak_service.dart';

class SessionStatsRecorder {
  SessionStatsRecorder({
    required SettingsRepositoryBase settingsRepository,
    required StudyStreakService studyStreakService,
  }) : _settingsRepository = settingsRepository,
       _studyStreakService = studyStreakService;

  final SettingsRepositoryBase _settingsRepository;
  final StudyStreakService _studyStreakService;

  Future<DailySessionStats> record({
    required int cardsCompleted,
    required Duration elapsed,
    DateTime? now,
  }) async {
    final resolvedNow = now ?? DateTime.now();
    var todayStats = _settingsRepository.readDailySessionStats(now: resolvedNow);
    if (cardsCompleted <= 0) {
      return todayStats;
    }

    todayStats = todayStats.addSession(
      cards: cardsCompleted,
      sessionDuration: elapsed,
      now: resolvedNow,
    );
    await _settingsRepository.setDailySessionStats(todayStats);
    await _studyStreakService.recordCompletedSession(now: resolvedNow);
    return todayStats;
  }
}
