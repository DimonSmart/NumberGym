import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/language_router.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/progress_manager.dart';
import 'package:number_gym/features/training/domain/session_lifecycle_tracker.dart';
import 'package:number_gym/features/training/domain/task_progress_recorder.dart';
import 'package:number_gym/features/training/domain/task_state.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_outcome.dart';
import 'package:number_gym/features/training/domain/training_task.dart';

import 'helpers/training_fakes.dart';

void main() {
  test(
    'records affecting progress attempts and increments session counter',
    () async {
      final settings = FakeSettingsRepository();
      final repository = InMemoryProgressRepository();
      final languageRouter = LanguageRouter(
        settingsRepository: settings,
        random: Random(1),
      );
      final progressManager = ProgressManager(
        progressRepository: repository,
        languageRouter: languageRouter,
      );
      final tracker = SessionLifecycleTracker()
        ..reset(targetCards: 20, now: DateTime(2026, 2, 10, 12, 0));
      final recorder = TaskProgressRecorder(
        progressManager: progressManager,
        sessionTracker: tracker,
      );
      final taskId = const TrainingItemId(
        type: TrainingItemType.digits,
        number: 7,
      );
      final state = MultipleChoiceState(
        kind: LearningMethod.numberPronunciation,
        taskId: taskId,
        numberValue: 7,
        displayText: '7',
        timer: TimerState.zero,
        prompt: '7',
        options: const <String>['seven'],
      );

      final update = await recorder.record(
        taskState: state,
        outcome: TrainingOutcome.correct,
        language: LearningLanguage.english,
      );

      expect(update.affectsProgress, isTrue);
      expect(update.isCorrect, isTrue);
      expect(update.isSkipped, isFalse);
      expect(tracker.cardsCompleted, 1);

      final progress = repository.read(taskId, LearningLanguage.english);
      expect(progress.totalAttempts, 1);
      expect(progress.totalCorrect, 1);
    },
  );

  test('skips persistence for non-progress tasks', () async {
    final settings = FakeSettingsRepository();
    final repository = InMemoryProgressRepository();
    final languageRouter = LanguageRouter(
      settingsRepository: settings,
      random: Random(2),
    );
    final progressManager = ProgressManager(
      progressRepository: repository,
      languageRouter: languageRouter,
    );
    final tracker = SessionLifecycleTracker()
      ..reset(targetCards: 20, now: DateTime(2026, 2, 10, 12, 0));
    final recorder = TaskProgressRecorder(
      progressManager: progressManager,
      sessionTracker: tracker,
    );
    final taskId = const TrainingItemId(
      type: TrainingItemType.base,
      number: 42,
    );
    final state = PhrasePronunciationState(
      taskId: taskId,
      numberValue: 42,
      displayText: 'forty two',
      flow: PhraseFlow.waiting,
      hasRecording: false,
      result: null,
      isWaveVisible: false,
    );

    final update = await recorder.record(
      taskState: state,
      outcome: TrainingOutcome.skipped,
      language: LearningLanguage.english,
    );

    expect(update.affectsProgress, isFalse);
    expect(tracker.cardsCompleted, 0);
    expect(repository.read(taskId, LearningLanguage.english).totalAttempts, 0);
  });
}
