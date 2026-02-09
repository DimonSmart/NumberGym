import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:number_gym/features/training/data/settings_repository.dart';
import 'package:number_gym/features/training/domain/daily_session_stats.dart';

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
}
