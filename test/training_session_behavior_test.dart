import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/task_registry.dart';
import 'package:number_gym/features/training/domain/task_runtime.dart';
import 'package:number_gym/features/training/domain/task_state.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_outcome.dart';
import 'package:number_gym/features/training/domain/training_session.dart';
import 'package:number_gym/features/training/domain/training_services.dart';
import 'package:number_gym/features/training/domain/training_task.dart';

import 'helpers/training_fakes.dart';

void main() {
  test(
    'startTraining attaches runtime and stopTraining clears state',
    () async {
      final keepAwake = FakeKeepAwakeService();
      final session = _buildSession(
        taskRegistry: _buildScriptedRegistry(
          onStart: (ignoredMethod, ignoredTaskId) => const <TaskEvent>[],
        ),
        services: buildFakeTrainingServices(keepAwake: keepAwake),
      );

      await session.initialize();
      await session.startTraining();

      expect(session.state.currentTask, isNotNull);
      expect(keepAwake.calls, contains(true));

      await session.stopTraining();
      await _waitFor(() => keepAwake.calls.contains(false));

      expect(session.state.currentTask, isNull);
      expect(session.state.feedback, isNull);
      session.dispose();
    },
  );

  test('auto-stop is triggered after silent streak threshold', () async {
    var autoStops = 0;
    final session = _buildSession(
      taskRegistry: _buildScriptedRegistry(
        onStart: (ignoredMethod, ignoredTaskId) => const <TaskEvent>[
          TaskCompleted(TrainingOutcome.skipped),
        ],
      ),
      onAutoStop: () {
        autoStops += 1;
      },
    );

    await session.initialize();
    await session.startTraining();
    await _waitFor(() => autoStops == 1);

    expect(session.state.currentTask, isNull);
    expect(session.sessionCardsCompleted, greaterThanOrEqualTo(3));
    session.dispose();
  });

  test('session reaches card limit when user interacts', () async {
    final session = _buildSession(
      taskRegistry: _buildScriptedRegistry(
        onStart: (ignoredMethod, ignoredTaskId) => const <TaskEvent>[
          TaskUserInteracted(),
          TaskCompleted(TrainingOutcome.skipped),
        ],
      ),
    );

    await session.initialize();
    await session.startTraining();
    await _waitFor(() => session.state.sessionStats != null);

    final stats = session.state.sessionStats!;
    expect(stats.cardsCompleted, session.sessionTargetCards);
    expect(stats.cardsCompleted, 50);
    session.dispose();
  });

  test('queues celebration when card transitions to learned', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final repository = InMemoryProgressRepository(
      seeded: {
        repoStorageKey(_timeRandomId, _language): CardProgress(
          learned: false,
          clusters: <CardCluster>[
            CardCluster(
              lastAnswerAt: now,
              correctCount: 19,
              wrongCount: 0,
              skippedCount: 0,
            ),
          ],
          learnedAt: 0,
          firstAttemptAt: now,
        ),
      },
    );
    final session = _buildSession(
      progressRepository: repository,
      taskRegistry: _buildScriptedRegistry(
        onStart: (ignoredMethod, ignoredTaskId) => const <TaskEvent>[
          TaskUserInteracted(),
          TaskCompleted(TrainingOutcome.correct),
        ],
      ),
    );

    await session.initialize();
    await session.startTraining();
    await _waitFor(() => session.state.celebration != null);

    final celebration = session.state.celebration!;
    expect(celebration.categoryLabel, isNotEmpty);
    expect(celebration.cardsLearnedTotal, greaterThanOrEqualTo(1));
    session.dispose();
  });

  test('uses fixed card duration by item type', () async {
    Future<void> expectDuration({
      required TrainingItemType type,
      required Duration expected,
    }) async {
      Duration? capturedDuration;
      final session = TrainingSession(
        settingsRepository: FakeSettingsRepository(
          language: _language,
          forcedMethod: LearningMethod.numberPronunciation,
          forcedItemType: type,
        ),
        progressRepository: InMemoryProgressRepository(),
        services: buildFakeTrainingServices(),
        taskRegistry: TaskRegistry({
          for (final method in LearningMethod.values)
            method: (context) {
              capturedDuration = context.cardDuration;
              return _ScriptedRuntime(
                method: method,
                taskId: context.card.id,
                onStartEvents: const <TaskEvent>[],
              );
            },
        }),
      );

      await session.initialize();
      await session.startTraining();
      await _waitFor(() => capturedDuration != null);
      expect(capturedDuration, expected);

      await session.stopTraining();
      session.dispose();
    }

    await expectDuration(
      type: TrainingItemType.digits,
      expected: const Duration(seconds: 10),
    );
    await expectDuration(
      type: TrainingItemType.base,
      expected: const Duration(seconds: 15),
    );
    await expectDuration(
      type: TrainingItemType.timeRandom,
      expected: const Duration(seconds: 15),
    );
    await expectDuration(
      type: TrainingItemType.phone33x3,
      expected: const Duration(seconds: 30),
    );
  });
}

const LearningLanguage _language = LearningLanguage.english;
const TrainingItemId _timeRandomId = TrainingItemId(
  type: TrainingItemType.timeRandom,
);

TrainingSession _buildSession({
  required TaskRegistry taskRegistry,
  InMemoryProgressRepository? progressRepository,
  TrainingServices? services,
  void Function()? onAutoStop,
}) {
  return TrainingSession(
    settingsRepository: FakeSettingsRepository(
      language: _language,
      forcedMethod: LearningMethod.numberPronunciation,
      forcedItemType: TrainingItemType.timeRandom,
    ),
    progressRepository: progressRepository ?? InMemoryProgressRepository(),
    services: services ?? buildFakeTrainingServices(),
    taskRegistry: taskRegistry,
    onAutoStop: onAutoStop,
  );
}

TaskRegistry _buildScriptedRegistry({
  required List<TaskEvent> Function(LearningMethod, TrainingItemId) onStart,
}) {
  return TaskRegistry({
    for (final method in LearningMethod.values)
      method: (context) => _ScriptedRuntime(
        method: method,
        taskId: context.card.id,
        onStartEvents: onStart(method, context.card.id),
      ),
  });
}

class _ScriptedRuntime extends TaskRuntimeBase {
  _ScriptedRuntime({
    required this.method,
    required this.taskId,
    required this.onStartEvents,
  }) : super(
         MultipleChoiceState(
           kind: method,
           taskId: taskId,
           numberValue: null,
           displayText: '12:34',
           timer: TimerState.zero,
           prompt: 'prompt',
           options: const <String>['a', 'b'],
         ),
       );

  final LearningMethod method;
  final TrainingItemId taskId;
  final List<TaskEvent> onStartEvents;

  @override
  Future<void> start() async {
    for (final event in onStartEvents) {
      emitEvent(event);
    }
  }

  @override
  Future<void> handleAction(TaskAction action) async {
    if (action is RefreshTimerAction) {
      emitState(state);
    }
  }

  @override
  Future<void> onTimerTimeout() async {}
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for expected condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
