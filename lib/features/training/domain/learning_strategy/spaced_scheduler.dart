import '../../data/card_progress.dart';
import 'learning_params.dart';

class SpacedScheduleResult {
  final CardProgress progress;
  final bool clusterSuccess;
  final bool countedSuccess;

  const SpacedScheduleResult({
    required this.progress,
    required this.clusterSuccess,
    required this.countedSuccess,
  });
}

class SpacedScheduler {
  final LearningParams params;

  const SpacedScheduler(this.params);

  SpacedScheduleResult applyClusterResult({
    required CardProgress progress,
    required double accuracy,
    required DateTime now,
  }) {
    final clusterSuccess = accuracy >= params.clusterSuccessAccuracy;

    final baseInterval =
        progress.intervalDays > 0 ? progress.intervalDays : params.initialIntervalDays;
    final baseEase = progress.ease > 0 ? progress.ease : params.initialEase;

    double nextEase;
    double nextInterval;
    if (clusterSuccess) {
      nextEase = params.clampEase(baseEase + params.easeUpOnSuccess);
      nextInterval = params.clampInterval(baseInterval * nextEase);
    } else {
      nextEase = params.clampEase(baseEase - params.easeDownOnFail);
      nextInterval = params.clampInterval(
        baseInterval * params.failIntervalFactor,
      );
    }

    var spacedSuccessCount = progress.spacedSuccessCount;
    var lastCountedSuccessDay = progress.lastCountedSuccessDay;
    var countedSuccess = false;

    if (clusterSuccess) {
      final nowDay = _dayStamp(now);
      final canCount = lastCountedSuccessDay < 0 ||
          nowDay - lastCountedSuccessDay >=
              params.minDaysBetweenCountedSuccesses;
      if (canCount) {
        spacedSuccessCount += 1;
        lastCountedSuccessDay = nowDay;
        countedSuccess = true;
      }
    }

    final learned = progress.learned ||
        (spacedSuccessCount >= params.minSpacedSuccessClusters &&
            nextInterval >= params.learnedIntervalDays);

    final nextDueMillis = now.millisecondsSinceEpoch +
        (nextInterval * Duration.millisecondsPerDay).round();

    final updated = progress.copyWith(
      learned: learned,
      intervalDays: nextInterval,
      nextDue: nextDueMillis,
      ease: nextEase,
      spacedSuccessCount: spacedSuccessCount,
      lastCountedSuccessDay: lastCountedSuccessDay,
    );

    return SpacedScheduleResult(
      progress: updated,
      clusterSuccess: clusterSuccess,
      countedSuccess: countedSuccess,
    );
  }

  bool isLearned(CardProgress progress) {
    return progress.learned ||
        (progress.spacedSuccessCount >= params.minSpacedSuccessClusters &&
            progress.intervalDays >= params.learnedIntervalDays);
  }

  int _dayStamp(DateTime now) {
    final localMidnight = DateTime(now.year, now.month, now.day);
    return localMidnight.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }
}
