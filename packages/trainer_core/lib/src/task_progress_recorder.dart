import 'core/logging/app_logger.dart';
import 'progress_manager.dart';
import 'session_lifecycle_tracker.dart';
import 'trainer_state.dart';
import 'training/domain/learning_language.dart';

class TaskProgressUpdate {
  const TaskProgressUpdate({
    required this.affectsProgress,
    required this.isCorrect,
    required this.isSkipped,
    required this.learned,
  });

  final bool affectsProgress;
  final bool isCorrect;
  final bool isSkipped;
  final bool learned;
}

class TaskProgressRecorder {
  TaskProgressRecorder({
    required ProgressManager progressManager,
    required SessionLifecycleTracker sessionTracker,
  }) : _progressManager = progressManager,
       _sessionTracker = sessionTracker;

  final ProgressManager _progressManager;
  final SessionLifecycleTracker _sessionTracker;

  Future<TaskProgressUpdate> record({
    required TaskState taskState,
    required TrainingOutcome outcome,
    required LearningLanguage language,
  }) async {
    if (!taskState.affectsProgress) {
      appLogI(
        'progress',
        'Attempt: mode=${taskState.mode.name} id=${taskState.exerciseId} '
            'outcome=${outcome.name} affectsProgress=false',
      );
      return const TaskProgressUpdate(
        affectsProgress: false,
        isCorrect: false,
        isSkipped: false,
        learned: false,
      );
    }

    final isCorrect = outcome == TrainingOutcome.correct;
    final isSkipped =
        outcome == TrainingOutcome.timeout ||
        outcome == TrainingOutcome.skipped;
    _sessionTracker.incrementCompleted();

    final attemptResult = await _progressManager.recordAttempt(
      progressKey: taskState.exerciseId,
      isCorrect: isCorrect,
      isSkipped: isSkipped,
      language: language,
    );
    appLogI(
      'progress',
      'Attempt: mode=${taskState.mode.name} id=${taskState.exerciseId} '
          'outcome=${outcome.name} correct=$isCorrect skipped=$isSkipped '
          'cluster=${attemptResult.newCluster ? 'new' : 'existing'}',
    );
    return TaskProgressUpdate(
      affectsProgress: true,
      isCorrect: isCorrect,
      isSkipped: isSkipped,
      learned: attemptResult.learned,
    );
  }
}
