import '../core/logging/app_logger.dart';
import '../exercise_models.dart';
import '../task_runtime.dart';
import '../trainer_services.dart';
import '../trainer_state.dart';

class ChoiceRuntime extends TaskRuntimeBase {
  ChoiceRuntime({
    required ExerciseMode mode,
    required ExerciseCard card,
    required ChoiceExerciseSpec spec,
    required Duration cardDuration,
    required CardTimerBase cardTimer,
  }) : _mode = mode,
       _card = card,
       _spec = spec,
       _cardDuration = cardDuration,
       _cardTimer = cardTimer,
       super(
         ChoiceState(
           mode: mode,
           exerciseId: card.id,
           family: card.family,
           displayText: spec.prompt,
           promptText: card.promptText,
           acceptedAnswers: card.acceptedAnswers,
           celebrationText: card.celebrationText,
           timer: TimerState(
             isRunning: false,
             duration: cardDuration,
             remaining: cardDuration,
           ),
           options: spec.options,
         ),
       );

  final ExerciseMode _mode;
  final ExerciseCard _card;
  final ChoiceExerciseSpec _spec;
  final Duration _cardDuration;
  final CardTimerBase _cardTimer;
  bool _completed = false;

  @override
  Future<void> start() async {
    if (_completed) {
      return;
    }
    _cardTimer.start(_cardDuration, _onTimerTimeout);
    emitState(_buildState());
  }

  @override
  Future<void> handleAction(TaskAction action) async {
    if (_completed) {
      return;
    }
    if (action is RefreshTimerAction) {
      emitState(_buildState());
      return;
    }
    if (action is PauseTaskAction) {
      _cardTimer.pause();
      emitState(_buildState());
      return;
    }
    if (action is ResumeTaskAction) {
      _cardTimer.resume();
      emitState(_buildState());
      return;
    }
    if (action is! SelectOptionAction) {
      return;
    }
    emitEvent(const TaskUserInteracted());
    final normalized = action.option.trim().toLowerCase();
    final correct = _spec.correctOption.trim().toLowerCase();
    final outcome = normalized == correct
        ? TrainingOutcome.correct
        : TrainingOutcome.wrong;
    appLogI(
      'task',
      'Answer: mode=${_mode.name} id=${_card.id} '
          'selected="${action.option}" correct="${_spec.correctOption}" '
          'outcome=${outcome.name}',
    );
    await _complete(outcome);
  }

  @override
  Future<void> onTimerTimeout() async {
    if (_completed) {
      return;
    }
    await _complete(TrainingOutcome.timeout);
  }

  @override
  Future<void> dispose() async {
    _cardTimer.stop();
    await super.dispose();
  }

  ChoiceState _buildState() {
    return ChoiceState(
      mode: _mode,
      exerciseId: _card.id,
      family: _card.family,
      displayText: _spec.prompt,
      promptText: _card.promptText,
      acceptedAnswers: _card.acceptedAnswers,
      celebrationText: _card.celebrationText,
      timer: TimerState(
        isRunning: _cardTimer.isRunning,
        duration: _cardTimer.duration,
        remaining: _cardTimer.remaining(),
      ),
      options: _spec.options,
    );
  }

  Future<void> _onTimerTimeout() async {
    await onTimerTimeout();
  }

  Future<void> _complete(TrainingOutcome outcome) async {
    if (_completed) {
      return;
    }
    _completed = true;
    _cardTimer.stop();
    emitState(_buildState());
    emitEvent(TaskCompleted(outcome));
  }
}
