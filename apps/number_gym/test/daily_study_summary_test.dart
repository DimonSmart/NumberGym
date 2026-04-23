import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/daily_study_summary.dart';

void main() {
  test('daily summary tracks attempts and remaining limits', () {
    final now = DateTime(2026, 2, 7, 12, 0);
    final todayAttemptTime = DateTime(2026, 2, 7, 9, 30);
    final item = CardProgress(
      learned: false,
      clusters: <CardCluster>[
        CardCluster(
          lastAnswerAt: todayAttemptTime.millisecondsSinceEpoch,
          correctCount: 2,
          wrongCount: 1,
          skippedCount: 0,
        ),
      ],
      learnedAt: 0,
      firstAttemptAt: todayAttemptTime.millisecondsSinceEpoch,
    );

    final summary = DailyStudySummary.fromProgress(
      <CardProgress>[item],
      now: now,
      dailyAttemptLimit: 10,
      dailyNewCardsLimit: 3,
    );

    expect(summary.targetToday, 10);
    expect(summary.completedToday, 3);
    expect(summary.remainingToday, 7);
    expect(summary.newCardsToday, 1);
    expect(summary.newCardsRemaining, 2);
    expect(summary.nextDue, isNull);
  });

  test('daily summary recommends next day when daily limit reached', () {
    final now = DateTime(2026, 2, 7, 23, 0);
    final todayAttemptTime = DateTime(2026, 2, 7, 8, 5);
    final item = CardProgress(
      learned: false,
      clusters: <CardCluster>[
        CardCluster(
          lastAnswerAt: todayAttemptTime.millisecondsSinceEpoch,
          correctCount: 4,
          wrongCount: 1,
          skippedCount: 0,
        ),
      ],
      learnedAt: 0,
      firstAttemptAt: todayAttemptTime.millisecondsSinceEpoch,
    );

    final summary = DailyStudySummary.fromProgress(
      <CardProgress>[item],
      now: now,
      dailyAttemptLimit: 5,
      dailyNewCardsLimit: 10,
    );

    expect(summary.completedToday, 5);
    expect(summary.remainingToday, 0);
    expect(summary.nextDue, DateTime(2026, 2, 8));
  });
}
