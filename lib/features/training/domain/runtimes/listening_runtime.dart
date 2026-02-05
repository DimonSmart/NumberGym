import '../../../../core/logging/app_logger.dart';
import '../services/card_timer.dart';
import '../services/tts_service.dart';
import '../task_runtime.dart';
import '../task_state.dart';
import '../time_value.dart';
import '../training_item.dart';
import '../training_outcome.dart';
import '../training_task.dart';

class ListeningRuntime extends TaskRuntimeBase {
  ListeningRuntime({
    required TrainingItemId taskId,
    int? numberValue,
    TimeValue? timeValue,
    required String correctAnswer,
    required List<String> options,
    required String speechText,
    required Duration cardDuration,
    required CardTimerBase cardTimer,
    required TtsServiceBase ttsService,
    required String locale,
    String? voiceId,
  })  : _taskId = taskId,
        _numberValue = numberValue,
        _timeValue = timeValue,
        _correctAnswer = correctAnswer,
        _options = List<String>.unmodifiable(options),
        _speechText = speechText,
        _cardDuration = cardDuration,
        _cardTimer = cardTimer,
        _ttsService = ttsService,
        _locale = locale,
        _voiceId = voiceId,
        super(
          ListeningState(
            taskId: taskId,
            numberValue: numberValue,
            timeValue: timeValue,
            displayText: _hiddenPrompt,
            timer: TimerState(
              isRunning: false,
              duration: cardDuration,
              remaining: cardDuration,
            ),
            options: options,
            isAnswerRevealed: false,
          ),
        );

  static const String _hiddenPrompt = '?';

  final TrainingItemId _taskId;
  final int? _numberValue;
  final TimeValue? _timeValue;
  final String _correctAnswer;
  final List<String> _options;
  final String _speechText;
  final Duration _cardDuration;
  final CardTimerBase _cardTimer;
  final TtsServiceBase _ttsService;
  final String _locale;
  final String? _voiceId;

  bool _completed = false;
  bool _answerRevealed = false;
  Future<void>? _voicePreparation;

  @override
  Future<void> start() async {
    if (_completed) return;
    _cardTimer.start(_cardDuration, _onTimerTimeout);
    emitState(_buildState());
    await _speak();
  }

  @override
  Future<void> handleAction(TaskAction action) async {
    if (_completed) return;
    if (action is RepeatPromptAction) {
      emitEvent(const TaskUserInteracted());
      await _speak();
      return;
    }
    if (action is! SelectOptionAction) return;
    emitEvent(const TaskUserInteracted());
    final normalized = action.option.trim();
    final outcome = normalized == _correctAnswer
        ? TrainingOutcome.correct
        : TrainingOutcome.wrong;
    appLogI(
      'task',
      'Answer: kind=${TrainingTaskKind.listening.name} id=$_taskId '
      'selected="${action.option}" correct="$_correctAnswer" '
      'outcome=${outcome.name}',
    );
    if (outcome == TrainingOutcome.correct) {
      _answerRevealed = true;
      emitState(_buildState());
    }
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

  ListeningState _buildState() {
    return ListeningState(
      taskId: _taskId,
      numberValue: _numberValue,
      timeValue: _timeValue,
      displayText: _answerRevealed ? _correctAnswer : _hiddenPrompt,
      timer: TimerState(
        isRunning: _cardTimer.isRunning,
        duration: _cardTimer.duration,
        remaining: _cardTimer.remaining(),
      ),
      options: _options,
      isAnswerRevealed: _answerRevealed,
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

  Future<void> _prepareVoice() {
    final existing = _voicePreparation;
    if (existing != null) return existing;
    final prepared = _configureVoice();
    _voicePreparation = prepared;
    return prepared;
  }

  Future<void> _configureVoice() async {
    final voices = await _ttsService.listVoices();
    if (voices.isEmpty) return;
    final filtered = filterVoicesByLocale(voices, _locale);
    if (filtered.isEmpty) return;
    TtsVoice? selected;
    final voiceId = _voiceId?.trim();
    if (voiceId != null && voiceId.isNotEmpty) {
      for (final voice in filtered) {
        if (voice.id == voiceId) {
          selected = voice;
          break;
        }
      }
    }
    selected ??= filtered.first;
    await _ttsService.setVoice(selected);
  }

  Future<void> _speak() async {
    await _prepareVoice();
    await _ttsService.speak(_speechText);
  }
}
