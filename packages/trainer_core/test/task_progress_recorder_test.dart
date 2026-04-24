import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

import 'helpers/training_fakes.dart';

const _moduleId = 'test';

final _testFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'test_family',
  label: 'Test',
  shortLabel: 'Test',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.chooseFromPrompt],
);

class _TestModule implements TrainingModule {
  @override
  String get moduleId => _moduleId;

  @override
  String get displayName => 'Test';

  @override
  bool supportsLanguage(LearningLanguage language) =>
      language == LearningLanguage.english;

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) => [
    _testFamily,
  ];

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    return List.generate(10, (i) {
      final id = ExerciseId(
        moduleId: _moduleId,
        familyId: 'test_family',
        variantId: '$i',
      );
      return ExerciseCard(
        id: id,
        family: _testFamily,
        language: language,
        displayText: '$i',
        promptText: '$i',
        acceptedAnswers: ['option_$i'],
        celebrationText: '$i',
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: '$i',
          correctOption: 'option_$i',
          options: ['option_$i', 'other_1', 'other_2', 'other_3'],
        ),
      );
    });
  }
}

void main() {
  test(
    'records affecting progress attempts and increments session counter',
    () async {
      final progressRepository = InMemoryProgressRepository();
      final progressManager = ProgressManager(
        progressRepository: progressRepository,
        catalog: ExerciseCatalog(modules: [_TestModule()]),
      );
      await progressManager.loadProgress(LearningLanguage.english);

      final tracker = SessionLifecycleTracker()
        ..reset(targetCards: 20, now: DateTime(2026, 2, 10, 12, 0));
      final recorder = TaskProgressRecorder(
        progressManager: progressManager,
        sessionTracker: tracker,
      );

      const taskId = ExerciseId(
        moduleId: _moduleId,
        familyId: 'test_family',
        variantId: '7',
      );
      final state = ChoiceState(
        mode: ExerciseMode.chooseFromPrompt,
        exerciseId: taskId,
        family: _testFamily,
        displayText: '7',
        promptText: '7',
        acceptedAnswers: const <String>['option_7'],
        celebrationText: '7',
        timer: TimerState.zero,
        options: const <String>['option_7', 'other_1', 'other_2', 'other_3'],
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

      // Verify progress was written
      final stored = await progressRepository.loadAll([
        taskId.storageKey,
      ], language: LearningLanguage.english);
      expect(stored[taskId.storageKey]!.totalAttempts, 1);
      expect(stored[taskId.storageKey]!.totalCorrect, 1);
    },
  );

  test('skips persistence for non-progress tasks', () async {
    final progressRepository = InMemoryProgressRepository();
    final progressManager = ProgressManager(
      progressRepository: progressRepository,
      catalog: ExerciseCatalog(modules: [_TestModule()]),
    );
    await progressManager.loadProgress(LearningLanguage.english);

    final tracker = SessionLifecycleTracker()
      ..reset(targetCards: 20, now: DateTime(2026, 2, 10, 12, 0));
    final recorder = TaskProgressRecorder(
      progressManager: progressManager,
      sessionTracker: tracker,
    );

    const taskId = ExerciseId(
      moduleId: _moduleId,
      familyId: 'test_family',
      variantId: '3',
    );

    // ReviewPronunciationState has affectsProgress: false
    final state = ReviewPronunciationState(
      exerciseId: taskId,
      family: _testFamily,
      displayText: 'forty two',
      promptText: 'forty two',
      acceptedAnswers: const <String>['forty two'],
      celebrationText: 'forty two',
      flow: ReviewFlow.waiting,
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

    final stored = await progressRepository.loadAll([
      taskId.storageKey,
    ], language: LearningLanguage.english);
    expect(stored[taskId.storageKey]!.totalAttempts, 0);
  });
}
