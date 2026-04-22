import 'dart:math' as math;

import 'training/data/card_progress.dart';

class DailyStudyPlan {
  static const int cardLimit = 50;
  static const int newCardsLimit = 15;
}

class DailyStudySummary {
  const DailyStudySummary({
    required this.completedToday,
    required this.targetToday,
    required this.remainingToday,
    required this.nextDue,
    required this.newCardsToday,
    required this.newCardsRemaining,
  });

  final int completedToday;
  final int targetToday;
  final int remainingToday;
  final DateTime? nextDue;
  final int newCardsToday;
  final int newCardsRemaining;

  factory DailyStudySummary.fromProgress(
    Iterable<CardProgress> progressItems, {
    DateTime? now,
    int dailyAttemptLimit = DailyStudyPlan.cardLimit,
    int dailyNewCardsLimit = DailyStudyPlan.newCardsLimit,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final startOfDay = DateTime(
      resolvedNow.year,
      resolvedNow.month,
      resolvedNow.day,
    );
    final endOfDayMillis =
        startOfDay.add(const Duration(days: 1)).millisecondsSinceEpoch - 1;
    final startOfDayMillis = startOfDay.millisecondsSinceEpoch;

    var completedToday = 0;
    var newCardsToday = 0;
    for (final progress in progressItems) {
      completedToday += _attemptsInDayWindow(
        progress,
        startOfDayMillis: startOfDayMillis,
        endOfDayMillis: endOfDayMillis,
      );
      final firstAttemptAt = progress.firstAttemptAt;
      if (firstAttemptAt >= startOfDayMillis &&
          firstAttemptAt <= endOfDayMillis) {
        newCardsToday += 1;
      }
    }

    final targetToday = dailyAttemptLimit;
    final remainingToday = math.max(0, targetToday - completedToday);
    return DailyStudySummary(
      completedToday: completedToday,
      targetToday: targetToday,
      remainingToday: remainingToday,
      nextDue: remainingToday == 0
          ? startOfDay.add(const Duration(days: 1))
          : null,
      newCardsToday: newCardsToday,
      newCardsRemaining: math.max(0, dailyNewCardsLimit - newCardsToday),
    );
  }

  static int _attemptsInDayWindow(
    CardProgress progress, {
    required int startOfDayMillis,
    required int endOfDayMillis,
  }) {
    var attempts = 0;
    for (final cluster in progress.clusters) {
      final lastAnswerAt = cluster.lastAnswerAt;
      if (lastAnswerAt < startOfDayMillis || lastAnswerAt > endOfDayMillis) {
        continue;
      }
      attempts += cluster.totalAttempts;
    }
    return attempts;
  }
}
