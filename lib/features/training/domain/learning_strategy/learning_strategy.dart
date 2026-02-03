import '../../data/card_progress.dart';
import '../training_item.dart';
import 'learning_params.dart';
import 'learning_queue.dart';
import 'learning_state.dart';
import 'spaced_scheduler.dart';

class LearningClusterResult {
  final CardProgress progress;
  final bool learnedNow;
  final bool clusterSuccess;
  final bool countedSuccess;

  const LearningClusterResult({
    required this.progress,
    required this.learnedNow,
    required this.clusterSuccess,
    required this.countedSuccess,
  });
}

abstract class LearningStrategy {
  LearningParams get params;
  LearningQueue get queue;

  List<LearningState> pickNextStates({
    required DateTime now,
    required int limit,
    required Map<TrainingItemId, CardProgress> progressById,
    bool Function(TrainingItemId id)? isEligible,
  });

  LearningClusterResult applyClusterResult({
    required TrainingItemId itemId,
    required CardProgress progress,
    required double accuracy,
    required DateTime now,
  });

  bool isLearned(CardProgress progress);

  factory LearningStrategy.defaults({
    required LearningQueue queue,
    LearningParams? params,
  }) {
    final resolvedParams = params ?? LearningParams.defaults();
    return DefaultLearningStrategy(
      queue: queue,
      params: resolvedParams,
    );
  }
}

class DefaultLearningStrategy implements LearningStrategy {
  DefaultLearningStrategy({
    required LearningQueue queue,
    required LearningParams params,
  })  : _queue = queue,
        _params = params,
        _scheduler = SpacedScheduler(params);

  final LearningQueue _queue;
  final LearningParams _params;
  final SpacedScheduler _scheduler;

  @override
  LearningParams get params => _params;

  @override
  LearningQueue get queue => _queue;

  @override
  List<LearningState> pickNextStates({
    required DateTime now,
    required int limit,
    required Map<TrainingItemId, CardProgress> progressById,
    bool Function(TrainingItemId id)? isEligible,
  }) {
    if (limit <= 0) return const <LearningState>[];
    _queue.fillActive(isEligible: isEligible);
    final filtered = <LearningState>[];
    for (final id in _queue.active) {
      if (isEligible != null && !isEligible(id)) {
        continue;
      }
      final progress = progressById[id] ?? CardProgress.empty;
      filtered.add(LearningState(id: id, progress: progress));
    }
    if (filtered.isEmpty) return const <LearningState>[];
    final nowMillis = now.millisecondsSinceEpoch;
    filtered.sort((a, b) {
      final aDue = a.progress.nextDue > 0 ? a.progress.nextDue : nowMillis;
      final bDue = b.progress.nextDue > 0 ? b.progress.nextDue : nowMillis;
      final dueCompare = aDue.compareTo(bDue);
      if (dueCompare != 0) return dueCompare;
      return a.id.compareTo(b.id);
    });
    if (filtered.length <= limit) return filtered;
    return filtered.sublist(0, limit);
  }

  @override
  LearningClusterResult applyClusterResult({
    required TrainingItemId itemId,
    required CardProgress progress,
    required double accuracy,
    required DateTime now,
  }) {
    final scheduleResult = _scheduler.applyClusterResult(
      progress: progress,
      accuracy: accuracy,
      now: now,
    );
    final learnedNow = !progress.learned && scheduleResult.progress.learned;
    if (learnedNow) {
      _queue.removeFromActive(itemId);
      _queue.fillActive();
    }
    return LearningClusterResult(
      progress: scheduleResult.progress,
      learnedNow: learnedNow,
      clusterSuccess: scheduleResult.clusterSuccess,
      countedSuccess: scheduleResult.countedSuccess,
    );
  }

  @override
  bool isLearned(CardProgress progress) => _scheduler.isLearned(progress);
}
