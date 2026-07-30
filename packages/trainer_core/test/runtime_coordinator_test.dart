import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:trainer_core/src/runtime_coordinator.dart';

import 'helpers/training_fakes.dart';

final _family = ExerciseFamily(
  moduleId: 'test',
  id: 'family',
  label: 'Test',
  shortLabel: 'Test',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: const Duration(seconds: 1),
  supportedModes: const [ExerciseMode.chooseFromPrompt],
);

ChoiceState _state() => ChoiceState(
  mode: ExerciseMode.chooseFromPrompt,
  exerciseId: const ExerciseId(
    moduleId: 'test',
    familyId: 'family',
    variantId: '1',
  ),
  family: _family,
  displayText: 'one',
  promptText: 'one',
  acceptedAnswers: const ['one'],
  celebrationText: 'one',
  timer: TimerState.zero,
  options: const ['one'],
);

void main() {
  test(
    'detach completes best-effort cleanup after cancellation failure',
    () async {
      var deliveredEvents = 0;
      final coordinator = RuntimeCoordinator(
        onChanged: () {},
        onEvent: (_) => deliveredEvents += 1,
      );
      final runtime = ControllableTaskRuntime(initialState: _state())
        ..throwOnCancellation = true;
      final handle = await coordinator.attach(runtime);

      await expectLater(
        coordinator.detach(handle: handle, clearState: true),
        throwsA(isA<StateError>()),
      );

      runtime.emitTestEvent(const TaskCompleted(TrainingOutcome.correct));
      await Future<void>.delayed(Duration.zero);
      expect(runtime.disposeCalls, 1);
      expect(coordinator.currentHandle, isNull);
      expect(deliveredEvents, 0);
    },
  );

  test('close prevents an attach waiting for prior disposal from becoming active',
      () async {
    final coordinator = RuntimeCoordinator(onChanged: () {}, onEvent: (_) {});
    final first = ControllableTaskRuntime(
      initialState: _state(),
      blockDispose: true,
    );
    await coordinator.attach(first);
    final second = ControllableTaskRuntime(initialState: _state());

    final attaching = coordinator.attach(second);
    await Future<void>.delayed(Duration.zero);
    final closing = coordinator.close();
    first.disposeGate.complete();

    await expectLater(attaching, throwsA(isA<StateError>()));
    await closing;
    expect(coordinator.currentHandle, isNull);
    expect(second.disposeCalls, 0);
    await coordinator.close();
  });

  test('concurrent attaches retain only the latest runtime', () async {
    final coordinator = RuntimeCoordinator(onChanged: () {}, onEvent: (_) {});
    final first = ControllableTaskRuntime(initialState: _state());
    final second = ControllableTaskRuntime(initialState: _state());

    final firstHandle = coordinator.attach(first);
    final secondHandle = coordinator.attach(second);
    await firstHandle;
    final handle = await secondHandle;

    expect(first.disposeCalls, 1);
    expect(coordinator.currentHandle, same(handle));
    expect(coordinator.runtime, same(second));
  });
}
