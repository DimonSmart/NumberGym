import 'dart:math' as math;

import 'daily_study_summary.dart';

class SessionProgressPlan {
  const SessionProgressPlan._();

  static int normalizeSessionSize(int configuredSize) {
    return configuredSize > 0 ? configuredSize : DailyStudyPlan.cardLimit;
  }

  static int startedSessions({
    required int cardsCompletedToday,
    required int sessionSize,
  }) {
    final normalizedCards = cardsCompletedToday < 0 ? 0 : cardsCompletedToday;
    final normalizedSessionSize = normalizeSessionSize(sessionSize);
    if (normalizedCards == 0) {
      return 1;
    }
    return (normalizedCards + normalizedSessionSize - 1) ~/
        normalizedSessionSize;
  }

  static int cardsToFinishCurrentSession({
    required int cardsCompletedToday,
    required int sessionSize,
  }) {
    final normalizedCards = cardsCompletedToday < 0 ? 0 : cardsCompletedToday;
    final normalizedSessionSize = normalizeSessionSize(sessionSize);
    final completedInCurrentSession = normalizedCards % normalizedSessionSize;
    if (completedInCurrentSession == 0) {
      return normalizedSessionSize;
    }
    return normalizedSessionSize - completedInCurrentSession;
  }

  static int targetCards({
    required int cardsCompletedToday,
    required int sessionsCompleted,
    required int sessionSize,
  }) {
    final normalizedSessionSize = normalizeSessionSize(sessionSize);
    final plannedSessions = math.max(
      startedSessions(
        cardsCompletedToday: cardsCompletedToday,
        sessionSize: normalizedSessionSize,
      ),
      math.max(1, sessionsCompleted < 0 ? 0 : sessionsCompleted),
    );
    return plannedSessions * normalizedSessionSize;
  }

  static int currentSessionProgress({
    required int cardsCompletedToday,
    required int sessionSize,
  }) {
    final normalizedSessionSize = normalizeSessionSize(sessionSize);
    final normalizedCards = cardsCompletedToday < 0 ? 0 : cardsCompletedToday;
    return normalizedCards % normalizedSessionSize;
  }
}
