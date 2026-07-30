import 'dart:async';

import 'core/logging/app_logger.dart';
import 'serialized_operation_queue.dart';
import 'task_runtime.dart';
import 'trainer_state.dart';

final class RuntimeHandle {
  const RuntimeHandle({required this.generation, required this.runtime});

  final int generation;
  final TaskRuntime runtime;
}

final class RuntimeAttachTicket {
  const RuntimeAttachTicket(this.cancellationEpoch);

  final int cancellationEpoch;
}

final class RuntimeAttachCancelled implements Exception {
  const RuntimeAttachCancelled();
}

final class RuntimeEventEnvelope {
  const RuntimeEventEnvelope({required this.generation, required this.event});

  final int generation;
  final TaskEvent event;
}

final class RuntimeClaim {
  RuntimeClaim._({
    required this.handle,
    required this.taskState,
    required StreamSubscription<TaskEvent>? events,
    required StreamSubscription<TaskState>? states,
  }) : _events = events,
       _states = states;

  final RuntimeHandle handle;
  final TaskState taskState;
  StreamSubscription<TaskEvent>? _events;
  StreamSubscription<TaskState>? _states;
  bool _disposed = false;
}

final class RuntimeCancellationFailure {
  const RuntimeCancellationFailure({
    required this.generation,
    required this.error,
    required this.stackTrace,
  });

  final int generation;
  final Object error;
  final StackTrace stackTrace;
}

/// Owns the active runtime. Generation invalidation happens synchronously before
/// asynchronous cleanup, so stale callbacks cannot affect current state.
final class RuntimeCoordinator {
  RuntimeCoordinator({
    required void Function() onChanged,
    required void Function(RuntimeEventEnvelope event) onEvent,
  }) : _onChanged = onChanged,
       _onEvent = onEvent;

  final void Function() _onChanged;
  final void Function(RuntimeEventEnvelope event) _onEvent;
  final SerializedOperationQueue _lifecycleOperations =
      SerializedOperationQueue();

  RuntimeHandle? _currentHandle;
  StreamSubscription<TaskEvent>? _runtimeEvents;
  StreamSubscription<TaskState>? _runtimeStates;
  TaskState? _currentTaskState;
  bool _speechReady = false;
  bool _taskHadUserInteraction = false;
  int _generation = 0;
  int _attachmentCancellationEpoch = 0;
  bool _closeRequested = false;
  Future<void>? _closeFuture;
  RuntimeCancellationFailure? _cancellationFailure;

  RuntimeHandle? get currentHandle => _currentHandle;
  TaskRuntime? get runtime => _currentHandle?.runtime;
  TaskState? get currentTask => _currentTaskState;
  bool get speechReady => _speechReady;
  bool get taskHadUserInteraction => _taskHadUserInteraction;
  bool get hasRuntime => _currentHandle != null;

  bool isCurrent(RuntimeHandle handle) =>
      identical(_currentHandle, handle) && handle.generation == _generation;

  RuntimeAttachTicket createAttachTicket() =>
      RuntimeAttachTicket(_attachmentCancellationEpoch);

  void resetInteraction() => _taskHadUserInteraction = false;

  void updateSpeechReady(bool ready) {
    if (_speechReady == ready) return;
    _speechReady = ready;
    _onChanged();
  }

  Future<RuntimeHandle> attach(
    TaskRuntime runtime, {
    required RuntimeAttachTicket ticket,
  }) => _lifecycleOperations.enqueue(() => _attachCore(runtime, ticket));

  bool _isAttachCancelled(RuntimeAttachTicket ticket) =>
      _closeRequested ||
      ticket.cancellationEpoch != _attachmentCancellationEpoch;

  Future<RuntimeHandle> _attachCore(
    TaskRuntime runtime,
    RuntimeAttachTicket ticket,
  ) async {
    RuntimeHandle? handle;
    try {
      if (_isAttachCancelled(ticket)) {
        appLogD(
          'trainer',
          'runtime attach cancelled before ownership: ticket=${ticket.cancellationEpoch}',
        );
        throw const RuntimeAttachCancelled();
      }
      await _disposeCurrentCore(clearState: true);
      if (_isAttachCancelled(ticket)) {
        appLogD(
          'trainer',
          'runtime attach cancelled after previous disposal: ticket=${ticket.cancellationEpoch}',
        );
        throw const RuntimeAttachCancelled();
      }
      // No await occurs between this check and ownership assignment.
      if (_isAttachCancelled(ticket)) throw const RuntimeAttachCancelled();
      final attachedHandle = RuntimeHandle(
        generation: ++_generation,
        runtime: runtime,
      );
      handle = attachedHandle;
      _currentHandle = attachedHandle;
      _taskHadUserInteraction = false;
      _runtimeEvents = runtime.events.listen(
        (event) => _handleTaskEvent(attachedHandle, event),
      );
      _runtimeStates = runtime.states.listen(
        (state) => _handleTaskState(attachedHandle, state),
      );
      _currentTaskState = runtime.state;
      if (_currentTaskState is SpeakState) {
        _speechReady = (_currentTaskState as SpeakState).speechReady;
      }
      _onChanged();
      await runtime.start();
      if (_isAttachCancelled(ticket)) throw const RuntimeAttachCancelled();
      return attachedHandle;
    } catch (error, stackTrace) {
      if (handle != null && isCurrent(handle)) {
        try {
          await _detachCore(handle: handle, clearState: true);
        } catch (cleanupError, cleanupStackTrace) {
          appLogE(
            'trainer',
            'Secondary cleanup failure after runtime attach: generation=${handle.generation}',
            error: cleanupError,
            st: cleanupStackTrace,
          );
        }
      } else {
        try {
          await runtime.dispose();
        } catch (cleanupError, cleanupStackTrace) {
          appLogE(
            'trainer',
            'Secondary cleanup failure for rejected runtime attach',
            error: cleanupError,
            st: cleanupStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  RuntimeClaim? claimCurrentForCompletion({required RuntimeHandle target}) {
    if (!isCurrent(target)) return null;
    final state = _currentTaskState;
    if (state == null) return null;
    ++_generation;
    _currentHandle = null;
    _currentTaskState = null;
    final claim = RuntimeClaim._(
      handle: target,
      taskState: state,
      events: _runtimeEvents,
      states: _runtimeStates,
    );
    _runtimeEvents = null;
    _runtimeStates = null;
    _onChanged();
    appLogD(
      'trainer',
      'runtime claim committed: generation=${target.generation}',
    );
    return claim;
  }

  Future<void> disposeClaim(RuntimeClaim claim) =>
      _lifecycleOperations.enqueue(() => _disposeClaimCore(claim));

  Future<void> _disposeClaimCore(RuntimeClaim claim) async {
    if (claim._disposed) return;
    claim._disposed = true;
    await _disposeOwnedRuntime(
      handle: claim.handle,
      events: claim._events,
      states: claim._states,
    );
    claim._events = null;
    claim._states = null;
  }

  Future<void> detach({
    required RuntimeHandle handle,
    required bool clearState,
  }) => _lifecycleOperations.enqueue(
    () => _detachCore(handle: handle, clearState: clearState),
  );

  Future<void> _detachCore({
    required RuntimeHandle handle,
    required bool clearState,
  }) async {
    if (!isCurrent(handle)) return;
    _requestCancellationCurrent();
    ++_generation;
    _currentHandle = null;
    final events = _runtimeEvents;
    final states = _runtimeStates;
    _runtimeEvents = null;
    _runtimeStates = null;
    if (clearState) _currentTaskState = null;
    _onChanged();
    await _disposeOwnedRuntime(handle: handle, events: events, states: states);
  }

  Future<void> _disposeOwnedRuntime({
    required RuntimeHandle handle,
    required StreamSubscription<TaskEvent>? events,
    required StreamSubscription<TaskState>? states,
  }) async {
    final cancellationFailure = _takeCancellationFailure(handle.generation);
    Object? firstError = cancellationFailure?.error;
    StackTrace? firstStackTrace = cancellationFailure?.stackTrace;
    Future<void> attempt(Future<void> Function() operation) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await attempt(() => events?.cancel() ?? Future<void>.value());
    await attempt(() => states?.cancel() ?? Future<void>.value());
    await attempt(handle.runtime.dispose);
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> disposeCurrent({required bool clearState}) =>
      _lifecycleOperations.enqueue(
        () => _disposeCurrentCore(clearState: clearState),
      );

  Future<void> _disposeCurrentCore({required bool clearState}) async {
    final handle = _currentHandle;
    if (handle == null) {
      if (clearState && _currentTaskState != null) {
        _currentTaskState = null;
        _onChanged();
      }
      return;
    }
    await _detachCore(handle: handle, clearState: clearState);
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
    _attachmentCancellationEpoch += 1;
    _requestCancellationCurrent();
  }

  void _requestCancellationCurrent() {
    final handle = _currentHandle;
    if (handle == null) return;
    try {
      handle.runtime.requestCancellation();
    } catch (error, stackTrace) {
      if (_cancellationFailure?.generation != handle.generation) {
        _cancellationFailure = RuntimeCancellationFailure(
          generation: handle.generation,
          error: error,
          stackTrace: stackTrace,
        );
      }
      appLogE(
        'trainer',
        'Runtime cancellation signal failed: generation=${handle.generation}',
        error: error,
        st: stackTrace,
      );
    }
  }

  Future<void> close() {
    _closeRequested = true;
    _attachmentCancellationEpoch += 1;
    _requestCancellationCurrent();
    return _closeFuture ??= _lifecycleOperations
        .enqueue(() => _disposeCurrentCore(clearState: true))
        .whenComplete(_lifecycleOperations.close);
  }

  RuntimeCancellationFailure? _takeCancellationFailure(int generation) {
    final failure = _cancellationFailure;
    if (failure?.generation != generation) return null;
    _cancellationFailure = null;
    return failure;
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
    if (!isCurrent(handle)) {
      appLogD(
        'trainer',
        'late runtime state ignored: generation=${handle.generation}',
      );
      return;
    }
    _currentTaskState = state;
    if (state is SpeakState) _speechReady = state.speechReady;
    _onChanged();
  }
}
