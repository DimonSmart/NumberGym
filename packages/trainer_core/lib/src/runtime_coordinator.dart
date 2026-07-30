import 'dart:async';

import 'task_runtime.dart';
import 'trainer_state.dart';

final class RuntimeHandle {
  const RuntimeHandle({required this.generation, required this.runtime});

  final int generation;
  final TaskRuntime runtime;
}

final class RuntimeEventEnvelope {
  const RuntimeEventEnvelope({required this.generation, required this.event});

  final int generation;
  final TaskEvent event;
}

final class RuntimeCompletion {
  const RuntimeCompletion({required this.handle, required this.taskState});

  final RuntimeHandle handle;
  final TaskState taskState;
}

/// Owns the active runtime. A generation is invalidated before any async
/// teardown, so a callback from an old runtime can never mutate current state.
final class RuntimeCoordinator {
  RuntimeCoordinator({
    required void Function() onChanged,
    required void Function(RuntimeEventEnvelope event) onEvent,
  }) : _onChanged = onChanged,
       _onEvent = onEvent;

  final void Function() _onChanged;
  final void Function(RuntimeEventEnvelope event) _onEvent;

  RuntimeHandle? _currentHandle;
  StreamSubscription<TaskEvent>? _runtimeEvents;
  StreamSubscription<TaskState>? _runtimeStates;
  TaskState? _currentTaskState;
  bool _speechReady = false;
  bool _taskHadUserInteraction = false;
  int _generation = 0;
  bool _closeRequested = false;
  Future<void>? _closeFuture;

  RuntimeHandle? get currentHandle => _currentHandle;
  TaskRuntime? get runtime => _currentHandle?.runtime;
  TaskState? get currentTask => _currentTaskState;
  bool get speechReady => _speechReady;
  bool get taskHadUserInteraction => _taskHadUserInteraction;
  bool get hasRuntime => _currentHandle != null;

  bool isCurrent(RuntimeHandle handle) =>
      identical(_currentHandle, handle) && handle.generation == _generation;

  void resetInteraction() => _taskHadUserInteraction = false;

  void updateSpeechReady(bool ready) {
    if (_speechReady == ready) return;
    _speechReady = ready;
    _onChanged();
  }

  Future<RuntimeHandle> attach(TaskRuntime runtime) async {
    if (_closeRequested) throw StateError('RuntimeCoordinator is closed.');
    await disposeCurrent(clearState: true);
    final handle = RuntimeHandle(generation: ++_generation, runtime: runtime);
    _currentHandle = handle;
    _taskHadUserInteraction = false;
    _runtimeEvents = runtime.events.listen(
      (event) => _handleTaskEvent(handle, event),
    );
    _runtimeStates = runtime.states.listen(
      (state) => _handleTaskState(handle, state),
    );
    _currentTaskState = runtime.state;
    if (_currentTaskState is SpeakState) {
      _speechReady = (_currentTaskState as SpeakState).speechReady;
    }
    _onChanged();
    try {
      await runtime.start();
    } catch (_) {
      if (isCurrent(handle)) await detach(handle: handle, clearState: true);
      rethrow;
    }
    return handle;
  }

  RuntimeCompletion? takeCurrentForCompletion({required RuntimeHandle target}) {
    if (!isCurrent(target)) return null;
    final handle = target;
    final state = _currentTaskState;
    if (state == null) return null;
    _currentTaskState = null;
    return RuntimeCompletion(handle: handle, taskState: state);
  }

  Future<void> detach({
    required RuntimeHandle handle,
    required bool clearState,
  }) async {
    if (!isCurrent(handle)) return;
    ++_generation;
    _currentHandle = null;
    final events = _runtimeEvents;
    final states = _runtimeStates;
    _runtimeEvents = null;
    _runtimeStates = null;
    if (clearState) _currentTaskState = null;
    _onChanged();
    Object? firstError;
    StackTrace? firstStackTrace;
    Future<void> attempt(Future<void> Function() operation) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await attempt(() async {
      handle.runtime.requestCancellation();
    });
    await attempt(() => events?.cancel() ?? Future<void>.value());
    await attempt(() => states?.cancel() ?? Future<void>.value());
    await attempt(handle.runtime.dispose);
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> disposeCurrent({required bool clearState}) async {
    final handle = _currentHandle;
    if (handle == null) {
      if (clearState && _currentTaskState != null) {
        _currentTaskState = null;
        _onChanged();
      }
      return;
    }
    await detach(handle: handle, clearState: clearState);
  }

  Future<void> disposeRuntime({required bool clearState}) =>
      disposeCurrent(clearState: clearState);

  Future<void> handleAction({
    required RuntimeHandle target,
    required TaskAction action,
  }) async {
    if (!isCurrent(target)) return;
    await target.runtime.handleAction(action);
  }

  void requestCancellation() {
    _currentHandle?.runtime.requestCancellation();
  }

  Future<void> close() {
    _closeRequested = true;
    return _closeFuture ??= disposeCurrent(clearState: true);
  }

  void _handleTaskEvent(RuntimeHandle handle, TaskEvent event) {
    if (!isCurrent(handle)) return;
    if (event is TaskUserInteracted) {
      _taskHadUserInteraction = true;
      return;
    }
    _onEvent(RuntimeEventEnvelope(generation: handle.generation, event: event));
  }

  void _handleTaskState(RuntimeHandle handle, TaskState state) {
    if (!isCurrent(handle)) return;
    _currentTaskState = state;
    if (state is SpeakState) _speechReady = state.speechReady;
    _onChanged();
  }
}
