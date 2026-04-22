import '../core/logging/app_logger.dart';
import '../exercise_models.dart';
import '../task_runtime.dart';
import '../trainer_services.dart';
import '../trainer_state.dart';

class ListenAndChooseRuntime extends TaskRuntimeBase {
  ListenAndChooseRuntime({
    required ExerciseCard card,
    required ListeningExerciseSpec spec,
    required Duration cardDuration,
    required CardTimerBase cardTimer,
    required TtsServiceBase ttsService,
    required String locale,
    String? voiceId,
  }) : _card = card,
       _spec = spec,
       _cardDuration = cardDuration,
       _cardTimer = cardTimer,
       _ttsService = ttsService,
       _locale = locale,
       _voiceId = voiceId,
       super(
         ListenAndChooseState(
           exerciseId: card.id,
           family: card.family,
           displayText: _hiddenPrompt,
           promptText: card.promptText,
           acceptedAnswers: card.acceptedAnswers,
           celebrationText: card.celebrationText,
           timer: TimerState(
             isRunning: false,
             duration: cardDuration,
             remaining: cardDuration,
           ),
           options: spec.options,
           correctAnswer: spec.correctOption,
           isAnswerRevealed: false,
           isPromptPlaying: false,
         ),
       );

  static const String _hiddenPrompt = '?';

  final ExerciseCard _card;
  final ListeningExerciseSpec _spec;
  final Duration _cardDuration;
  final CardTimerBase _cardTimer;
  final TtsServiceBase _ttsService;
  final String _locale;
  final String? _voiceId;

  bool _completed = false;
  bool _answerRevealed = false;
  bool _isPromptPlaying = false;
  bool _paused = false;
  bool _resumePromptAfterPause = false;
  Future<void>? _voicePreparation;

  @override
  Future<void> start() async {
    if (_completed) {
      return;
    }
    _cardTimer.start(_cardDuration, _onTimerTimeout);
    emitState(_buildState());
    await _speak();
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
      await _pauseForOverlay();
      return;
    }
    if (action is ResumeTaskAction) {
      await _resumeAfterOverlay();
      return;
    }
    if (_paused) {
      return;
    }
    if (action is RepeatPromptAction) {
      emitEvent(const TaskUserInteracted());
      await _speak();
      return;
    }
    if (action is! SelectOptionAction) {
      return;
    }
    emitEvent(const TaskUserInteracted());
    final outcome = action.option.trim() == _spec.correctOption
        ? TrainingOutcome.correct
        : TrainingOutcome.wrong;
    appLogI(
      'task',
      'Answer: mode=${ExerciseMode.listenAndChoose.name} id=${_card.id} '
          'selected="${action.option}" correct="${_spec.correctOption}" '
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

  ListenAndChooseState _buildState() {
    return ListenAndChooseState(
      exerciseId: _card.id,
      family: _card.family,
      displayText: _answerRevealed ? _spec.correctOption : _hiddenPrompt,
      promptText: _card.promptText,
      acceptedAnswers: _card.acceptedAnswers,
      celebrationText: _card.celebrationText,
      timer: TimerState(
        isRunning: _cardTimer.isRunning,
        duration: _cardTimer.duration,
        remaining: _cardTimer.remaining(),
      ),
      options: _spec.options,
      correctAnswer: _spec.correctOption,
      isAnswerRevealed: _answerRevealed,
      isPromptPlaying: _isPromptPlaying,
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

  Future<void> _prepareVoice() {
    final existing = _voicePreparation;
    if (existing != null) {
      return existing;
    }
    final prepared = _configureVoice();
    _voicePreparation = prepared;
    return prepared;
  }

  Future<void> _configureVoice() async {
    final voices = await _ttsService.listVoices();
    if (voices.isEmpty) {
      return;
    }
    final filtered = filterVoicesByLocale(voices, _locale);
    if (filtered.isEmpty) {
      return;
    }
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
    if (_completed || _paused) {
      return;
    }
    await _prepareVoice();
    if (_completed || _paused) {
      return;
    }
    _isPromptPlaying = true;
    emitState(_buildState());
    try {
      await _ttsService.speak(_spec.speechText);
    } finally {
      _isPromptPlaying = false;
      if (!_completed) {
        emitState(_buildState());
      }
    }
  }

  Future<void> _pauseForOverlay() async {
    if (_paused) {
      return;
    }
    _paused = true;
    _cardTimer.pause();
    _resumePromptAfterPause = _isPromptPlaying;
    if (_isPromptPlaying) {
      await _ttsService.stop();
      _isPromptPlaying = false;
    }
    emitState(_buildState());
  }

  Future<void> _resumeAfterOverlay() async {
    if (!_paused) {
      return;
    }
    _paused = false;
    _cardTimer.resume();
    emitState(_buildState());
    if (_resumePromptAfterPause) {
      _resumePromptAfterPause = false;
      await _speak();
    }
  }
}
