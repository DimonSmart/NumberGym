import 'dart:async';

import 'task_runtime.dart';
import 'task_state.dart';
import 'training_state.dart';

class RuntimeCoordinator {
  RuntimeCoordinator({
    required void Function() onChanged,
    required void Function(TaskEvent event) onEvent,
  })  : _onChanged = onChanged,
        _onEvent = onEvent;

  final void Function() _onChanged;
  final void Function(TaskEvent event) _onEvent;

  TaskRuntime? _runtime;
  StreamSubscription<TaskEvent>? _runtimeEvents;
  StreamSubscription<TaskState>? _runtimeStates;
  TaskState? _currentTaskState;

  TrainerStatus _status = TrainerStatus.idle;
  bool _speechReady = false;
  bool _taskHadUserInteraction = false;

  TrainerStatus get status => _status;
  TaskState? get currentTask => _currentTaskState;
  bool get speechReady => _speechReady;
  bool get taskHadUserInteraction => _taskHadUserInteraction;
  TaskRuntime? get runtime => _runtime;

  void setStatus(TrainerStatus status) {
    if (_status == status) return;
    _status = status;
    _onChanged();
  }

  void resetInteraction() {
    _taskHadUserInteraction = false;
  }

  void updateSpeechReady(bool ready) {
    if (_speechReady == ready) return;
    _speechReady = ready;
    _onChanged();
  }

  Future<void> attach(TaskRuntime runtime) async {
    await disposeRuntime(clearState: false);
    _runtime = runtime;
    _taskHadUserInteraction = false;
    _runtimeEvents = runtime.events.listen(_handleTaskEvent);
    _runtimeStates = runtime.states.listen(_handleTaskState);
    _currentTaskState = runtime.state;
    if (_currentTaskState is NumberPronunciationState) {
      _speechReady =
          (_currentTaskState as NumberPronunciationState).speechReady;
    }
    _status = TrainerStatus.running;
    _onChanged();
    await runtime.start();
  }

  Future<void> disposeRuntime({required bool clearState}) async {
    await _runtimeEvents?.cancel();
    await _runtimeStates?.cancel();
    _runtimeEvents = null;
    _runtimeStates = null;
    final runtime = _runtime;
    _runtime = null;
    if (runtime != null) {
      await runtime.dispose();
    }
    if (clearState) {
      _currentTaskState = null;
      _onChanged();
    }
  }

  Future<void> handleAction(TaskAction action) async {
    final runtime = _runtime;
    if (runtime == null) return;
    await runtime.handleAction(action);
  }

  void _handleTaskEvent(TaskEvent event) {
    if (event is TaskUserInteracted) {
      _taskHadUserInteraction = true;
      return;
    }
    _onEvent(event);
  }

  void _handleTaskState(TaskState state) {
    _currentTaskState = state;
    if (state is NumberPronunciationState) {
      _speechReady = state.speechReady;
    }
    _onChanged();
  }
}
