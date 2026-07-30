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
      final handle = await coordinator.attach(
        runtime,
        ticket: coordinator.createAttachTicket(),
      );

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

  test(
    'close prevents an attach waiting for prior disposal from becoming active',
    () async {
      final coordinator = RuntimeCoordinator(onChanged: () {}, onEvent: (_) {});
      final first = ControllableTaskRuntime(
        initialState: _state(),
        blockDispose: true,
      );
      await coordinator.attach(first, ticket: coordinator.createAttachTicket());
      final second = ControllableTaskRuntime(initialState: _state());

      final attaching = coordinator.attach(
        second,
        ticket: coordinator.createAttachTicket(),
      );
      await Future<void>.delayed(Duration.zero);
      final closing = coordinator.close();
      first.disposeGate.complete();

      await expectLater(attaching, throwsA(isA<RuntimeAttachCancelled>()));
      await closing;
      expect(coordinator.currentHandle, isNull);
      expect(second.disposeCalls, 1);
      await coordinator.close();
    },
  );

  test('concurrent attaches retain only the latest runtime', () async {
    final coordinator = RuntimeCoordinator(onChanged: () {}, onEvent: (_) {});
    final first = ControllableTaskRuntime(initialState: _state());
    final second = ControllableTaskRuntime(initialState: _state());

    final firstHandle = coordinator.attach(
      first,
      ticket: coordinator.createAttachTicket(),
    );
    final secondHandle = coordinator.attach(
      second,
      ticket: coordinator.createAttachTicket(),
    );
    await firstHandle;
    final handle = await secondHandle;

    expect(first.disposeCalls, 1);
    expect(coordinator.currentHandle, same(handle));
    expect(coordinator.runtime, same(second));
  });

  test(
    'cancellation rejects a pending attach and disposes its runtime once',
    () async {
      final coordinator = RuntimeCoordinator(onChanged: () {}, onEvent: (_) {});
      final first = ControllableTaskRuntime(
        initialState: _state(),
        blockDispose: true,
      );
      await coordinator.attach(first, ticket: coordinator.createAttachTicket());
      final second = ControllableTaskRuntime(initialState: _state());
      final attaching = coordinator.attach(
        second,
        ticket: coordinator.createAttachTicket(),
      );
      await Future<void>.delayed(Duration.zero);
      coordinator.requestCancellation();
      first.disposeGate.complete();

      await expectLater(attaching, throwsA(isA<RuntimeAttachCancelled>()));
      expect(second.startCalls, 0);
      expect(second.disposeCalls, 1);
      expect(coordinator.currentHandle, isNull);
    },
  );

  test(
    'completion claim immediately ignores late state before disposal',
    () async {
      var changes = 0;
      final coordinator = RuntimeCoordinator(
        onChanged: () => changes += 1,
        onEvent: (_) {},
      );
      final runtime = ControllableTaskRuntime(
        initialState: _state(),
        blockDispose: true,
      );
      final handle = await coordinator.attach(
        runtime,
        ticket: coordinator.createAttachTicket(),
      );
      final claim = coordinator.claimCurrentForCompletion(target: handle);
      expect(claim, isNotNull);
      final changesAfterClaim = changes;
      final disposing = coordinator.disposeClaim(claim!);
      runtime.emitTestState(_state());
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isCurrent(handle), isFalse);
      expect(coordinator.currentTask, isNull);
      expect(changes, changesAfterClaim);
      runtime.disposeGate.complete();
      await disposing;
      expect(runtime.disposeCalls, 1);
    },
  );

  test(
    'attach after close disposes runtime and reports cancellation',
    () async {
      final coordinator = RuntimeCoordinator(onChanged: () {}, onEvent: (_) {});
      await coordinator.close();
      final runtime = ControllableTaskRuntime(initialState: _state());

      await expectLater(
        coordinator.attach(runtime, ticket: coordinator.createAttachTicket()),
        throwsA(isA<RuntimeAttachCancelled>()),
      );

      expect(runtime.startCalls, 0);
      expect(runtime.disposeCalls, 1);
      expect(coordinator.currentHandle, isNull);
    },
  );

  test('repeated close is side-effect idempotent', () async {
    final coordinator = RuntimeCoordinator(onChanged: () {}, onEvent: (_) {});
    final runtime = ControllableTaskRuntime(initialState: _state());
    await coordinator.attach(runtime, ticket: coordinator.createAttachTicket());

    final firstClose = coordinator.close();
    final secondClose = coordinator.close();
    expect(identical(firstClose, secondClose), isTrue);
    await Future.wait([firstClose, secondClose]);

    expect(runtime.cancellationCalls, 1);
    expect(runtime.disposeCalls, 1);
    expect(coordinator.currentHandle, isNull);
  });
}
