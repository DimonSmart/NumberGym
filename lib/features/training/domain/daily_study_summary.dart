import 'dart:math' as math;

import '../data/card_progress.dart';

class DailyStudyPlan {
  static const int cardLimit = 50;
  static const Duration sessionTimeLimit = Duration(minutes: 10);
}

class DailyStudySummary {
  const DailyStudySummary({
    required this.dueToday,
    required this.completedToday,
    required this.targetToday,
    required this.remainingToday,
    required this.nextDue,
  });

  final int dueToday;
  final int completedToday;
  final int targetToday;
  final int remainingToday;
  final DateTime? nextDue;

  factory DailyStudySummary.fromProgress(
    Iterable<CardProgress> progressItems, {
    DateTime? now,
    int dailyLimit = DailyStudyPlan.cardLimit,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final startOfDay = DateTime(
      resolvedNow.year,
      resolvedNow.month,
      resolvedNow.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final endOfDayMillis = endOfDay.millisecondsSinceEpoch - 1;
    final startOfDayMillis = startOfDay.millisecondsSinceEpoch;

    var dueToday = 0;
    var completedToday = 0;
    int? earliestFutureDue;

    for (final progress in progressItems) {
      completedToday += _attemptsInDayWindow(
        progress,
        startOfDayMillis: startOfDayMillis,
        endOfDayMillis: endOfDayMillis,
      );

      if (progress.learned) {
        continue;
      }

      final dueMillis = progress.nextDue;
      if (dueMillis <= 0 || dueMillis <= endOfDayMillis) {
        dueToday += 1;
        continue;
      }

      if (earliestFutureDue == null || dueMillis < earliestFutureDue) {
        earliestFutureDue = dueMillis;
      }
    }

    final targetToday = math.min(dueToday, dailyLimit);
    final remainingToday = math.max(0, targetToday - completedToday);
    final nextDue = remainingToday == 0 && earliestFutureDue != null
        ? DateTime.fromMillisecondsSinceEpoch(earliestFutureDue)
        : null;

    return DailyStudySummary(
      dueToday: dueToday,
      completedToday: completedToday,
      targetToday: targetToday,
      remainingToday: remainingToday,
      nextDue: nextDue,
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
