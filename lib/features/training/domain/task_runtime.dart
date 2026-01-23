import 'dart:async';

import 'task_state.dart';
import 'training_outcome.dart';

sealed class TaskEvent {
  const TaskEvent();
}

final class TaskCompleted extends TaskEvent {
  const TaskCompleted(this.outcome);

  final TrainingOutcome outcome;
}

final class TaskUserInteracted extends TaskEvent {
  const TaskUserInteracted();
}

final class TaskError extends TaskEvent {
  const TaskError(this.message, {this.shouldPause = true});

  final String message;
  final bool shouldPause;
}

sealed class TaskAction {
  const TaskAction();
}

final class SelectOptionAction extends TaskAction {
  const SelectOptionAction(this.option);

  final String option;
}

final class RetrySpeechInitAction extends TaskAction {
  const RetrySpeechInitAction();
}

final class StartRecordingAction extends TaskAction {
  const StartRecordingAction();
}

final class StopRecordingAction extends TaskAction {
  const StopRecordingAction();
}

final class CancelRecordingAction extends TaskAction {
  const CancelRecordingAction();
}

final class SendRecordingAction extends TaskAction {
  const SendRecordingAction();
}

final class CompleteReviewAction extends TaskAction {
  const CompleteReviewAction();
}

abstract interface class TaskRuntime {
  TaskState get state;
  Stream<TaskState> get states;
  Stream<TaskEvent> get events;

  Future<void> start();
  Future<void> dispose();
  Future<void> handleAction(TaskAction action);
  Future<void> onTimerTimeout();
}

abstract class TaskRuntimeBase implements TaskRuntime {
  TaskRuntimeBase(TaskState initialState) : _state = initialState;

  final StreamController<TaskEvent> _eventController =
      StreamController<TaskEvent>.broadcast();
  final StreamController<TaskState> _stateController =
      StreamController<TaskState>.broadcast();

  TaskState _state;

  @override
  TaskState get state => _state;

  @override
  Stream<TaskEvent> get events => _eventController.stream;

  @override
  Stream<TaskState> get states => _stateController.stream;

  void emitState(TaskState state) {
    _state = state;
    if (_stateController.isClosed) return;
    _stateController.add(state);
  }

  void emitEvent(TaskEvent event) {
    if (_eventController.isClosed) return;
    _eventController.add(event);
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
    await _stateController.close();
  }
}
