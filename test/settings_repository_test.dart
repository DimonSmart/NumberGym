import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:number_gym/features/training/data/settings_repository.dart';
import 'package:number_gym/features/training/domain/daily_session_stats.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/study_streak.dart';

void main() {
  late Directory tempDir;
  late Box<String> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_repo_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    box = await Hive.openBox<String>('settings_repo_test');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('settings_repo_test');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('celebration counter defaults to zero', () {
    final repository = SettingsRepository(box);
    expect(repository.readCelebrationCounter(), 0);
  });

  test('celebration counter is persisted as non-negative value', () async {
    final repository = SettingsRepository(box);
    await repository.setCelebrationCounter(-3);
    expect(repository.readCelebrationCounter(), 0);

    await repository.setCelebrationCounter(7);
    expect(repository.readCelebrationCounter(), 7);
  });

  test('daily session stats default to zero for current day', () {
    final repository = SettingsRepository(box);
    final now = DateTime(2026, 2, 9, 9, 0);
    final stats = repository.readDailySessionStats(now: now);

    expect(stats.dayKey, DailySessionStats.dayKeyFor(now));
    expect(stats.sessionsCompleted, 0);
    expect(stats.cardsCompleted, 0);
    expect(stats.durationSeconds, 0);
  });

  test('daily session stats are persisted and normalized by day', () async {
    final repository = SettingsRepository(box);
    const stats = DailySessionStats(
      dayKey: '2026-02-09',
      sessionsCompleted: 2,
      cardsCompleted: 60,
      durationSeconds: 540,
    );

    await repository.setDailySessionStats(stats);

    final sameDay = repository.readDailySessionStats(
      now: DateTime(2026, 2, 9, 20, 0),
    );
    expect(sameDay.sessionsCompleted, 2);
    expect(sameDay.cardsCompleted, 60);
    expect(sameDay.durationSeconds, 540);

    final nextDay = repository.readDailySessionStats(
      now: DateTime(2026, 2, 10, 8, 0),
    );
    expect(nextDay.dayKey, '2026-02-10');
    expect(nextDay.sessionsCompleted, 0);
    expect(nextDay.cardsCompleted, 0);
    expect(nextDay.durationSeconds, 0);
  });

  test(
    'daily session duration is accumulated across all sessions today',
    () async {
      final repository = SettingsRepository(box);
      final now = DateTime(2026, 2, 9, 9, 0);

      var stats = repository.readDailySessionStats(now: now);
      stats = stats.addSession(
        cards: 20,
        sessionDuration: const Duration(minutes: 4, seconds: 15),
        now: now,
      );
      await repository.setDailySessionStats(stats);

      final later = DateTime(2026, 2, 9, 18, 0);
      stats = repository.readDailySessionStats(now: later);
      stats = stats.addSession(
        cards: 18,
        sessionDuration: const Duration(minutes: 3, seconds: 45),
        now: later,
      );
      await repository.setDailySessionStats(stats);

      final sameDay = repository.readDailySessionStats(
        now: DateTime(2026, 2, 9, 22, 0),
      );
      expect(sameDay.sessionsCompleted, 2);
      expect(sameDay.cardsCompleted, 38);
      expect(sameDay.durationSeconds, 480);
    },
  );

  test('daily session stats are scoped by learning language', () async {
    final repository = SettingsRepository(box);

    await repository.setLearningLanguage(LearningLanguage.english);
    await repository.setDailySessionStats(
      const DailySessionStats(
        dayKey: '2026-02-09',
        sessionsCompleted: 1,
        cardsCompleted: 20,
        durationSeconds: 300,
      ),
    );

    await repository.setLearningLanguage(LearningLanguage.spanish);
    final spanishStats = repository.readDailySessionStats(
      now: DateTime(2026, 2, 9, 9, 0),
    );
    expect(spanishStats.sessionsCompleted, 0);
    expect(spanishStats.cardsCompleted, 0);
    expect(spanishStats.durationSeconds, 0);

    await repository.setDailySessionStats(
      const DailySessionStats(
        dayKey: '2026-02-09',
        sessionsCompleted: 2,
        cardsCompleted: 35,
        durationSeconds: 420,
      ),
    );

    await repository.setLearningLanguage(LearningLanguage.english);
    final englishStats = repository.readDailySessionStats(
      now: DateTime(2026, 2, 9, 9, 0),
    );
    expect(englishStats.sessionsCompleted, 1);
    expect(englishStats.cardsCompleted, 20);
    expect(englishStats.durationSeconds, 300);
  });

  test('study streak defaults to empty value', () {
    final repository = SettingsRepository(box);
    final streak = repository.readStudyStreak();
    expect(streak.sessionsByDay, isEmpty);
    expect(streak.currentStreakDays(now: DateTime(2026, 2, 9, 9, 0)), 0);
  });

  test('study streak is persisted as day sessions map', () async {
    final repository = SettingsRepository(box);
    final streak = StudyStreak(
      sessionsByDay: const <String, int>{'2026-02-07': 1, '2026-02-08': 2},
    );

    await repository.setStudyStreak(streak);

    final restored = repository.readStudyStreak();
    expect(restored.sessionsByDay['2026-02-07'], 1);
    expect(restored.sessionsByDay['2026-02-08'], 2);
    expect(restored.currentStreakDays(now: DateTime(2026, 2, 9, 9, 0)), 2);
  });

  test('study streak is scoped by learning language', () async {
    final repository = SettingsRepository(box);

    await repository.setLearningLanguage(LearningLanguage.english);
    await repository.setStudyStreak(
      StudyStreak(sessionsByDay: const <String, int>{'2026-02-09': 1}),
    );

    await repository.setLearningLanguage(LearningLanguage.spanish);
    final spanishStreak = repository.readStudyStreak();
    expect(spanishStreak.sessionsByDay, isEmpty);

    await repository.setStudyStreak(
      StudyStreak(sessionsByDay: const <String, int>{'2026-02-09': 2}),
    );

    await repository.setLearningLanguage(LearningLanguage.english);
    final englishStreak = repository.readStudyStreak();
    expect(englishStreak.sessionsByDay['2026-02-09'], 1);
  });

  test(
    'resetProgressForLanguage clears only selected language stats',
    () async {
      final repository = SettingsRepository(box);

      await repository.setLearningLanguage(LearningLanguage.english);
      await repository.setDailySessionStats(
        const DailySessionStats(
          dayKey: '2026-02-09',
          sessionsCompleted: 1,
          cardsCompleted: 12,
          durationSeconds: 180,
        ),
      );
      await repository.setStudyStreak(
        StudyStreak(sessionsByDay: const <String, int>{'2026-02-09': 1}),
      );

      await repository.setLearningLanguage(LearningLanguage.spanish);
      await repository.setDailySessionStats(
        const DailySessionStats(
          dayKey: '2026-02-09',
          sessionsCompleted: 2,
          cardsCompleted: 24,
          durationSeconds: 360,
        ),
      );
      await repository.setStudyStreak(
        StudyStreak(sessionsByDay: const <String, int>{'2026-02-09': 2}),
      );

      await repository.resetProgressForLanguage(LearningLanguage.english);

      await repository.setLearningLanguage(LearningLanguage.english);
      final englishStats = repository.readDailySessionStats(
        now: DateTime(2026, 2, 9, 9, 0),
      );
      final englishStreak = repository.readStudyStreak();
      expect(englishStats.sessionsCompleted, 0);
      expect(englishStats.cardsCompleted, 0);
      expect(englishStats.durationSeconds, 0);
      expect(englishStreak.sessionsByDay, isEmpty);

      await repository.setLearningLanguage(LearningLanguage.spanish);
      final spanishStats = repository.readDailySessionStats(
        now: DateTime(2026, 2, 9, 9, 0),
      );
      final spanishStreak = repository.readStudyStreak();
      expect(spanishStats.sessionsCompleted, 2);
      expect(spanishStats.cardsCompleted, 24);
      expect(spanishStats.durationSeconds, 360);
      expect(spanishStreak.sessionsByDay['2026-02-09'], 2);
    },
  );
}
