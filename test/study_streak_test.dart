import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/study_streak.dart';
import 'package:number_gym/features/training/domain/study_streak_service.dart';

import 'helpers/training_fakes.dart';

void main() {
  test('streak resets to zero after a skipped day', () {
    final streak = StudyStreak(
      sessionsByDay: const <String, int>{
        '2026-02-05': 1,
        '2026-02-06': 1,
        '2026-02-07': 1,
      },
    );

    final streakDays = streak.currentStreakDays(now: DateTime(2026, 2, 9, 10));
    expect(streakDays, 0);
  });

  test('streak continues from yesterday when today has no sessions yet', () {
    final streak = StudyStreak(
      sessionsByDay: const <String, int>{
        '2026-02-06': 1,
        '2026-02-07': 1,
        '2026-02-08': 1,
      },
    );

    final streakDays = streak.currentStreakDays(now: DateTime(2026, 2, 9, 10));
    expect(streakDays, 3);
  });

  test('completed sessions are accumulated per day', () {
    var streak = StudyStreak.empty();

    streak = streak.addCompletedSession(now: DateTime(2026, 2, 9, 8, 0));
    streak = streak.addCompletedSession(now: DateTime(2026, 2, 9, 20, 0));
    streak = streak.addCompletedSession(now: DateTime(2026, 2, 10, 9, 0));

    expect(streak.sessionsByDay['2026-02-09'], 2);
    expect(streak.sessionsByDay['2026-02-10'], 1);
  });

  test('service snapshot marks days with multiple sessions', () {
    final repository = FakeSettingsRepository(
      streakByLanguage: {
        LearningLanguage.english: StudyStreak(
          sessionsByDay: const <String, int>{
            '2026-02-01': 1,
            '2026-02-02': 2,
            '2026-02-09': 1,
          },
        ),
      },
    );
    final service = StudyStreakService(settingsRepository: repository);

    final snapshot = service.readCurrentStreakSnapshot(
      now: DateTime(2026, 2, 9, 12, 0),
    );

    expect(snapshot.currentStreakDays, 1);
    expect(snapshot.monthDays.length, 28);
    expect(snapshot.monthDays[1].hasActivity, isTrue);
    expect(snapshot.monthDays[1].hasMultipleSessions, isTrue);
    expect(snapshot.monthDays[2].hasActivity, isFalse);
  });
}
