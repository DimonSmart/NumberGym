import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/daily_study_summary.dart';

void main() {
  test('daily summary counts attempts completed today', () {
    final now = DateTime(2026, 2, 7, 12, 0);
    final todayAttemptTime = DateTime(2026, 2, 7, 9, 30);
    final items = List<CardProgress>.generate(60, (index) {
      if (index != 0) {
        return CardProgress.empty;
      }
      return CardProgress(
        learned: false,
        clusters: <CardCluster>[
          CardCluster(
            lastAnswerAt: todayAttemptTime.millisecondsSinceEpoch,
            correctCount: 2,
            wrongCount: 1,
            skippedCount: 0,
          ),
        ],
        intervalDays: 0,
        nextDue: 0,
        ease: 0,
        spacedSuccessCount: 0,
        lastCountedSuccessDay: -1,
        learnedAt: 0,
      );
    });

    final summary = DailyStudySummary.fromProgress(items, now: now);

    expect(summary.dueToday, 60);
    expect(summary.targetToday, 50);
    expect(summary.completedToday, 3);
    expect(summary.remainingToday, 47);
  });

  test('daily summary ignores clusters outside today', () {
    final now = DateTime(2026, 2, 7, 12, 0);
    final yesterdayAttemptTime = DateTime(2026, 2, 6, 23, 20);
    final todayAttemptTime = DateTime(2026, 2, 7, 8, 5);
    final item = CardProgress(
      learned: false,
      clusters: <CardCluster>[
        CardCluster(
          lastAnswerAt: yesterdayAttemptTime.millisecondsSinceEpoch,
          correctCount: 2,
          wrongCount: 1,
          skippedCount: 0,
        ),
        CardCluster(
          lastAnswerAt: todayAttemptTime.millisecondsSinceEpoch,
          correctCount: 1,
          wrongCount: 0,
          skippedCount: 1,
        ),
      ],
      intervalDays: 0,
      nextDue: 0,
      ease: 0,
      spacedSuccessCount: 0,
      lastCountedSuccessDay: -1,
      learnedAt: 0,
    );

    final summary = DailyStudySummary.fromProgress(
      <CardProgress>[item],
      now: now,
      dailyLimit: 10,
    );

    expect(summary.dueToday, 1);
    expect(summary.targetToday, 1);
    expect(summary.completedToday, 2);
    expect(summary.remainingToday, 0);
  });
}
