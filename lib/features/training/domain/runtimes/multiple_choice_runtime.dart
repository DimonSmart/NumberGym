import '../../../../core/logging/app_logger.dart';
import '../services/card_timer.dart';
import '../task_runtime.dart';
import '../task_state.dart';
import '../training_item.dart';
import '../training_outcome.dart';
import '../training_task.dart';

class MultipleChoiceRuntime extends TaskRuntimeBase {
  MultipleChoiceRuntime({
    required TrainingTaskKind kind,
    required TrainingItemId taskId,
    required int? numberValue,
    required String prompt,
    required String correctOption,
    required List<String> options,
    required Duration cardDuration,
    required CardTimerBase cardTimer,
  })  : _kind = kind,
        _taskId = taskId,
        _correctOption = correctOption,
        _cardDuration = cardDuration,
        _cardTimer = cardTimer,
        super(
          MultipleChoiceState(
            kind: kind,
            taskId: taskId,
            numberValue: numberValue,
            displayText: prompt,
            timer: TimerState(
              isRunning: false,
              duration: cardDuration,
              remaining: cardDuration,
            ),
            prompt: prompt,
            options: options,
          ),
        );

  final TrainingTaskKind _kind;
  final TrainingItemId _taskId;
  final String _correctOption;
  final Duration _cardDuration;
  final CardTimerBase _cardTimer;
  bool _completed = false;

  @override
  Future<void> start() async {
    if (_completed) return;
    _cardTimer.start(_cardDuration, _onTimerTimeout);
    emitState(_buildState());
  }

  @override
  Future<void> handleAction(TaskAction action) async {
    if (_completed) return;
    if (action is! SelectOptionAction) return;
    emitEvent(const TaskUserInteracted());

    final normalized = action.option.trim().toLowerCase();
    final correct = _correctOption.trim().toLowerCase();
    final outcome = normalized == correct
        ? TrainingOutcome.correct
        : TrainingOutcome.wrong;
    appLogI(
      'task',
      'Answer: kind=${_kind.name} id=$_taskId '
      'selected="${action.option}" correct="$_correctOption" '
      'outcome=${outcome.name}',
    );
    await _complete(outcome);
  }

  @override
  Future<void> onTimerTimeout() async {
    if (_completed) return;
    await _complete(TrainingOutcome.timeout);
  }

  @override
  Future<void> dispose() async {
    _cardTimer.stop();
    await super.dispose();
  }

  MultipleChoiceState _buildState() {
    final current = state as MultipleChoiceState;
    return MultipleChoiceState(
      kind: _kind,
      taskId: current.taskId,
      numberValue: current.numberValue,
      displayText: current.displayText,
      timer: TimerState(
        isRunning: _cardTimer.isRunning,
        duration: _cardTimer.duration,
        remaining: _cardTimer.remaining(),
      ),
      prompt: current.prompt,
      options: current.options,
    );
  }

  Future<void> _onTimerTimeout() async {
    await onTimerTimeout();
  }

  Future<void> _complete(TrainingOutcome outcome) async {
    if (_completed) return;
    _completed = true;
    _cardTimer.stop();
    emitState(_buildState());
    emitEvent(TaskCompleted(outcome));
  }
}
