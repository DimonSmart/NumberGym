import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:trainer_core/src/task_runtime.dart';
import 'package:trainer_core/src/trainer_session.dart';

import 'helpers/training_fakes.dart';

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

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
        celebrationText: 'learned $i',
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: '$i',
          correctOption: 'option_$i',
          options: ['option_$i', 'other_1', 'other_2', 'other_3'],
        ),
      );
    });
  }
}

final _singleFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'single_family',
  label: 'Single',
  shortLabel: 'Single',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.chooseFromPrompt],
);

class _SingleCardModule implements TrainingModule {
  @override
  String get moduleId => _moduleId;

  @override
  String get displayName => 'Single';

  @override
  bool supportsLanguage(LearningLanguage language) =>
      language == LearningLanguage.english;

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) => [
    _singleFamily,
  ];

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    const id = ExerciseId(
      moduleId: _moduleId,
      familyId: 'single_family',
      variantId: '0',
    );
    return [
      ExerciseCard(
        id: id,
        family: _singleFamily,
        language: language,
        displayText: 'one',
        promptText: 'one',
        acceptedAnswers: const ['one'],
        celebrationText: 'learned one',
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: 'one',
          correctOption: 'one',
          options: const ['one', 'two', 'three', 'four'],
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _identityNormalizer(String text) => text.toLowerCase();

class _SimpleTokenizer implements MatcherTokenizer {
  @override
  List<MatchingToken> tokenize(String text) => [
    MatchingToken(display: text, normalized: text.toLowerCase()),
  ];
}

TrainingAppDefinition _buildAppDefinition({TrainingModule? module}) {
  const profile = BaseLanguageProfile(
    language: LearningLanguage.english,
    code: 'en',
    label: 'English',
    locale: 'en-US',
    textDirection: TextDirection.ltr,
    ttsPreviewText: 'test',
    preferredSpeechLocaleId: null,
    normalizer: _identityNormalizer,
  );
  return TrainingAppDefinition(
    config: const AppConfig(
      appId: 'test',
      title: 'Test',
      homeTitle: 'Test',
      repositoryUrl: 'https://example.com',
      privacyPolicyUrl: 'https://example.com/privacy',
      aboutTitle: 'About',
      aboutBody: 'Test',
      settingsBoxName: 'test_settings',
      progressBoxName: 'test_progress',
      heroAssetPath: 'assets/hero.png',
      mascotAssetPath: 'assets/mascot.png',
    ),
    supportedLanguages: [LearningLanguage.english],
    profileOf: (_) => profile,
    tokenizerOf: (_) => _SimpleTokenizer(),
    catalog: ExerciseCatalog(modules: [module ?? _TestModule()]),
  );
}

TrainerController _buildController({
  TrainingModule? module,
  InMemoryProgressRepository? progressRepository,
  VoidCallback? onAutoStop,
}) {
  return TrainerController(
    appDefinition: _buildAppDefinition(module: module),
    settingsRepository: FakeSettingsRepository(),
    progressRepository: progressRepository ?? InMemoryProgressRepository(),
    services: buildFakeTrainingServices(),
    onAutoStop: onAutoStop,
  );
}

TrainerSession _buildSession({
  TrainingModule? module,
  InMemoryProgressRepository? progressRepository,
  TrainingServices? services,
  TaskRuntimeFactory? runtimeFactory,
  VoidCallback? onStateChanged,
}) {
  return TrainerSession(
    appDefinition: _buildAppDefinition(module: module),
    settingsRepository: FakeSettingsRepository(),
    progressRepository: progressRepository ?? InMemoryProgressRepository(),
    services: services ?? buildFakeTrainingServices(),
    runtimeFactory: runtimeFactory,
    onStateChanged: onStateChanged,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test(
    'startTraining attaches runtime and stopTraining clears state',
    () async {
      final controller = _buildController();

      await controller.initialize();
      await controller.startTraining();

      expect(controller.currentTask, isNotNull);

      await controller.stopTraining();

      expect(controller.currentTask, isNull);
      expect(controller.state.feedback, isNull);
      controller.dispose();
    },
  );

  test('idle stop does not block a subsequent start', () async {
    final controller = _buildController();
    await controller.initialize();

    await controller.stopTraining();
    await controller.startTraining();

    expect(controller.phase, TrainerSessionPhase.active);
    expect(controller.currentTask, isNotNull);
    expect(controller.interactionEnabled, isTrue);
    await controller.disposeAsync();
  });

  test('repeated stops normalize and permit another start', () async {
    final controller = _buildController();
    await controller.initialize();
    await controller.startTraining();

    await Future.wait([controller.stopTraining(), controller.stopTraining()]);
    expect(controller.phase, TrainerSessionPhase.idle);
    expect(controller.currentTask, isNull);

    await controller.startTraining();
    expect(controller.phase, TrainerSessionPhase.active);
    expect(controller.currentTask, isNotNull);
    await controller.disposeAsync();
  });

  test(
    'session reaches card limit after completing sessionTargetCards',
    () async {
      final controller = _buildController();

      await controller.initialize();
      await controller.startTraining();

      expect(controller.currentTask, isNotNull);

      // Complete cards with user interaction to prevent auto-stop
      final target = controller.sessionTargetCards;
      for (var i = 0; i < target; i++) {
        await controller.completeCurrentTaskWithOutcome(
          TrainingOutcome.skipped,
          simulatedUserInteraction: true,
        );
      }

      expect(controller.state.sessionStats, isNotNull);
      expect(controller.state.sessionStats!.cardsCompleted, target);
      expect(controller.currentTask, isNull);
      expect(controller.phase, TrainerSessionPhase.sessionCompleted);
      expect(controller.interactionEnabled, isFalse);
      controller.dispose();
    },
  );

  test('continueSession clears sessionStats and resumes training', () async {
    final controller = _buildController();

    await controller.initialize();
    await controller.startTraining();

    final target = controller.sessionTargetCards;
    for (var i = 0; i < target; i++) {
      await controller.completeCurrentTaskWithOutcome(
        TrainingOutcome.skipped,
        simulatedUserInteraction: true,
      );
    }
    expect(controller.state.sessionStats, isNotNull);

    await controller.continueSession();

    expect(controller.state.sessionStats, isNull);
    expect(controller.currentTask, isNotNull);
    expect(controller.phase, TrainerSessionPhase.active);
    controller.dispose();
  });

  test('celebration fires when card transitions to learned', () async {
    // Seed card with 19 correct attempts so one more correct triggers learning
    const cardId = ExerciseId(
      moduleId: _moduleId,
      familyId: 'single_family',
      variantId: '0',
    );
    final progressRepository = InMemoryProgressRepository();
    await progressRepository.save(
      cardId.storageKey,
      const CardProgress(
        learned: false,
        clusters: <CardCluster>[
          CardCluster(
            lastAnswerAt: 1000, // 1970 — far enough back for a new cluster
            correctCount: 19,
            wrongCount: 0,
            skippedCount: 0,
          ),
        ],
        learnedAt: 0,
        firstAttemptAt: 1000,
        consecutiveCorrect: 19,
      ),
      language: LearningLanguage.english,
    );

    final controller = _buildController(
      module: _SingleCardModule(),
      progressRepository: progressRepository,
    );

    await controller.initialize();
    await controller.startTraining();

    expect(controller.currentTask, isNotNull);

    // One correct answer → total 20, accuracy 1.0 → learned!
    await controller.completeCurrentTaskWithOutcome(TrainingOutcome.correct);

    expect(controller.celebration, isNotNull);
    expect(controller.celebration!.categoryLabel, isNotEmpty);
    controller.dispose();
  });

  test('queued action is skipped after stop request', () async {
    late ControllableTaskRuntime runtime;
    final session = _buildSession(
      runtimeFactory: (card, mode, hintText) {
        runtime = ControllableTaskRuntime(
          initialState: _choiceStateForCard(card, mode),
        );
        return runtime;
      },
    );
    await session.initialize();
    await session.startTraining();
    runtime.handleActionGate = Completer<void>();

    final firstAction = session.handleAction(const SelectOptionAction('one'));
    await Future<void>.delayed(Duration.zero);
    final secondAction = session.handleAction(const SelectOptionAction('two'));
    final stop = session.stopTraining();
    runtime.handleActionGate!.complete();

    await Future.wait([firstAction, secondAction, stop]);
    expect(runtime.actions, hasLength(1));
    expect(runtime.actions.single, isA<SelectOptionAction>());
    expect(session.phase, TrainerSessionPhase.idle);
    expect(session.state.currentTask, isNull);
    await session.disposeAsync();
  });

  test(
    'queued pause and resume timer actions are skipped after stop request',
    () async {
      for (final command in <Future<void> Function(TrainerSession)>[
        (session) => session.pauseTaskTimer(),
        (session) => session.resumeTaskTimer(),
      ]) {
        late ControllableTaskRuntime runtime;
        final session = _buildSession(
          runtimeFactory: (card, mode, hintText) {
            runtime = ControllableTaskRuntime(
              initialState: _choiceStateForCard(card, mode),
            );
            return runtime;
          },
        );
        await session.initialize();
        await session.startTraining();
        runtime.handleActionGate = Completer<void>();

        final firstAction = session.handleAction(
          const SelectOptionAction('one'),
        );
        await Future<void>.delayed(Duration.zero);
        final timerAction = command(session);
        final stop = session.stopTraining();
        runtime.handleActionGate!.complete();

        await Future.wait([firstAction, timerAction, stop]);
        expect(runtime.actions.whereType<PauseTaskAction>(), isEmpty);
        expect(runtime.actions.whereType<ResumeTaskAction>(), isEmpty);
        expect(runtime.actions, hasLength(1));
        await session.disposeAsync();
      }
    },
  );

  test(
    'queued retry speech initialization is skipped after stop request',
    () async {
      late ControllableTaskRuntime runtime;
      final speech = FakeSpeechService();
      final session = _buildSession(
        services: buildFakeTrainingServices(speech: speech),
        runtimeFactory: (card, mode, hintText) {
          runtime = ControllableTaskRuntime(
            initialState: _choiceStateForCard(card, mode),
          );
          return runtime;
        },
      );
      await session.initialize();
      await session.startTraining();
      final initializeCallsAfterStart = speech.initializeCalls;
      runtime.handleActionGate = Completer<void>();

      final firstAction = session.handleAction(const SelectOptionAction('one'));
      await Future<void>.delayed(Duration.zero);
      final retry = session.retryInitSpeech();
      final stop = session.stopTraining();
      runtime.handleActionGate!.complete();

      await Future.wait([firstAction, retry, stop]);
      expect(speech.initializeCalls, initializeCallsAfterStart);
      expect(runtime.actions.whereType<RetrySpeechInitAction>(), isEmpty);
      await session.disposeAsync();
    },
  );

  test('completion publishes one coherent transition', () async {
    final states = <TrainingState>[];
    final session = _buildSession(onStateChanged: () {});
    session.onStateChanged = () => states.add(session.state);
    await session.initialize();
    await session.startTraining();

    await session.completeCurrentTaskWithOutcome(
      TrainingOutcome.skipped,
      simulatedUserInteraction: true,
    );

    expect(
      states,
      isNot(
        contains(
          isA<TrainingState>()
              .having(
                (state) => state.phase,
                'phase',
                TrainerSessionPhase.active,
              )
              .having((state) => state.currentTask, 'currentTask', isNull),
        ),
      ),
    );
    expect(
      states,
      contains(
        isA<TrainingState>()
            .having(
              (state) => state.phase,
              'phase',
              TrainerSessionPhase.transitioning,
            )
            .having((state) => state.currentTask, 'currentTask', isNull),
      ),
    );
    await session.disposeAsync();
  });

  test('debug invariant rejects active without task', () {
    final state = const TrainingState(
      errorMessage: null,
      feedback: null,
      currentTask: null,
      phase: TrainerSessionPhase.active,
    );

    expect(state.debugAssertInvariants, throwsA(isA<StateError>()));
  });

  test(
    'double completion records progress and starts next runtime once',
    () async {
      final progressRepository = InMemoryProgressRepository();
      final runtimes = <ControllableTaskRuntime>[];
      final session = _buildSession(
        progressRepository: progressRepository,
        runtimeFactory: (card, mode, hintText) {
          final runtime = ControllableTaskRuntime(
            initialState: _choiceStateForCard(card, mode),
          );
          runtimes.add(runtime);
          return runtime;
        },
      );
      await session.initialize();
      await session.startTraining();
      final firstRuntime = runtimes.single;

      final debugCompletion = session.completeCurrentTaskWithOutcome(
        TrainingOutcome.correct,
        simulatedUserInteraction: true,
      );
      firstRuntime.emitTestEvent(const TaskCompleted(TrainingOutcome.correct));
      await debugCompletion;
      await Future<void>.delayed(Duration.zero);

      expect(progressRepository.saveCalls, 1);
      expect(session.sessionCardsCompleted, 1);
      expect(runtimes, hasLength(2));
      await session.disposeAsync();
    },
  );
}

ChoiceState _choiceStateForCard(ExerciseCard card, ExerciseMode mode) =>
    ChoiceState(
      mode: mode,
      exerciseId: card.id,
      family: card.family,
      displayText: card.displayText,
      promptText: card.promptText,
      acceptedAnswers: card.acceptedAnswers,
      celebrationText: card.celebrationText,
      timer: TimerState.zero,
      options: card.chooseFromPrompt?.options ?? const <String>[],
    );
