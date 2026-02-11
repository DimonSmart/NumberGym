import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/session_stats_recorder.dart';
import 'package:number_gym/features/training/domain/study_streak_service.dart';

import 'helpers/training_fakes.dart';

void main() {
  test('record stores daily stats and updates streak', () async {
    final settings = FakeSettingsRepository();
    final streakService = StudyStreakService(settingsRepository: settings);
    final recorder = SessionStatsRecorder(
      settingsRepository: settings,
      studyStreakService: streakService,
    );
    final now = DateTime(2026, 2, 10, 10, 30);

    final stats = await recorder.record(
      cardsCompleted: 12,
      elapsed: const Duration(minutes: 4, seconds: 20),
      now: now,
    );

    expect(stats.sessionsCompleted, 1);
    expect(stats.cardsCompleted, 12);
    expect(stats.durationSeconds, 260);

    final saved = settings.readDailySessionStats(now: now);
    expect(saved.sessionsCompleted, 1);
    expect(saved.cardsCompleted, 12);
    expect(saved.durationSeconds, 260);

    final streak = settings.readStudyStreak();
    expect(streak.sessionsOn(now), 1);
  });

  test('record is no-op for zero cards', () async {
    final settings = FakeSettingsRepository();
    final streakService = StudyStreakService(settingsRepository: settings);
    final recorder = SessionStatsRecorder(
      settingsRepository: settings,
      studyStreakService: streakService,
    );
    final now = DateTime(2026, 2, 10, 11, 0);

    final stats = await recorder.record(
      cardsCompleted: 0,
      elapsed: const Duration(minutes: 2),
      now: now,
    );

    expect(stats.sessionsCompleted, 0);
    expect(stats.cardsCompleted, 0);
    expect(settings.readStudyStreak().sessionsByDay, isEmpty);
  });
}
