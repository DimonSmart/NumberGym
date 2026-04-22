import 'dart:async';
import 'dart:io';

import '../core/logging/app_logger.dart';
import '../exercise_models.dart';
import '../task_runtime.dart';
import '../trainer_services.dart';
import '../trainer_state.dart';

class ReviewPronunciationRuntime extends TaskRuntimeBase {
  ReviewPronunciationRuntime({
    required ExerciseCard card,
    required ReviewPronunciationSpec spec,
    required String locale,
    required AudioRecorderServiceBase audioRecorder,
    required SoundWaveServiceBase soundWaveService,
    required AzureSpeechService azureSpeechService,
  }) : _card = card,
       _spec = spec,
       _locale = locale,
       _audioRecorder = audioRecorder,
       _soundWaveService = soundWaveService,
       _azureSpeechService = azureSpeechService,
       super(
         ReviewPronunciationState(
           exerciseId: card.id,
           family: card.family,
           displayText: card.displayText,
           promptText: card.promptText,
           acceptedAnswers: card.acceptedAnswers,
           celebrationText: card.celebrationText,
           flow: ReviewFlow.waiting,
           hasRecording: false,
           result: null,
           isWaveVisible: false,
         ),
       );

  final ExerciseCard _card;
  final ReviewPronunciationSpec _spec;
  final String _locale;
  final AudioRecorderServiceBase _audioRecorder;
  final SoundWaveServiceBase _soundWaveService;
  final AzureSpeechService _azureSpeechService;

  StreamSubscription<double>? _recordingLevelSubscription;
  File? _recordingFile;
  PronunciationAnalysisResult? _result;
  ReviewFlow _flow = ReviewFlow.waiting;
  bool _disposed = false;

  @override
  Future<void> start() async {
    if (_disposed) {
      return;
    }
    emitState(_buildState());
  }

  @override
  Future<void> handleAction(TaskAction action) async {
    if (_disposed) {
      return;
    }
    if (action is StartRecordingAction) {
      await _startRecording();
    } else if (action is StopRecordingAction) {
      await _stopRecording();
    } else if (action is CancelRecordingAction) {
      await _cancelRecording();
    } else if (action is SendRecordingAction) {
      await _sendRecording();
    } else if (action is CompleteReviewAction) {
      await _completeReview();
    }
  }

  @override
  Future<void> onTimerTimeout() async {}

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _recordingLevelSubscription?.cancel();
    _recordingLevelSubscription = null;
    if (_audioRecorder.isRecording) {
      await _audioRecorder.cancel();
    }
    _soundWaveService.stop();
    await super.dispose();
  }

  ReviewPronunciationState _buildState() {
    return ReviewPronunciationState(
      exerciseId: _card.id,
      family: _card.family,
      displayText: _card.displayText,
      promptText: _card.promptText,
      acceptedAnswers: _card.acceptedAnswers,
      celebrationText: _card.celebrationText,
      flow: _flow,
      hasRecording: _recordingFile != null,
      result: _result,
      isWaveVisible: _flow == ReviewFlow.recording,
    );
  }

  Future<void> _startRecording() async {
    if (_flow == ReviewFlow.recording || _flow == ReviewFlow.sending) {
      return;
    }
    _recordingFile = null;
    _result = null;
    try {
      await _audioRecorder.start();
      _flow = ReviewFlow.recording;
      emitEvent(const TaskUserInteracted());
      await _startRecordingSoundWave();
      emitState(_buildState());
      _log('Pronunciation recording started.');
    } catch (error) {
      _flow = ReviewFlow.waiting;
      emitState(_buildState());
      emitEvent(TaskError('Cannot start recording: $error', shouldPause: false));
    }
  }

  Future<void> _stopRecording() async {
    if (_flow != ReviewFlow.recording) {
      return;
    }
    try {
      final file = await _audioRecorder.stop();
      _recordingFile = file;
      _flow = file == null ? ReviewFlow.waiting : ReviewFlow.recorded;
      await _stopRecordingSoundWave();
      emitState(_buildState());
    } catch (error) {
      _flow = ReviewFlow.waiting;
      await _stopRecordingSoundWave();
      emitState(_buildState());
      emitEvent(TaskError('Recording failed: $error', shouldPause: false));
    }
  }

  Future<void> _cancelRecording() async {
    if (_audioRecorder.isRecording) {
      await _audioRecorder.cancel();
    }
    await _stopRecordingSoundWave();
    _recordingFile = null;
    _result = null;
    _flow = ReviewFlow.waiting;
    emitState(_buildState());
  }

  Future<void> _sendRecording() async {
    final file = _recordingFile;
    if (file == null) {
      throw StateError('No recording to send');
    }
    if (_flow == ReviewFlow.sending) {
      return;
    }
    _flow = ReviewFlow.sending;
    emitState(_buildState());
    try {
      final result = await _azureSpeechService.analyzePronunciation(
        audioFile: file,
        expectedText: _spec.expectedText,
        language: _locale,
      );
      _result = result;
      _flow = ReviewFlow.reviewing;
      emitState(_buildState());
      appLogI(
        'task',
        'Answer: mode=${ExerciseMode.reviewPronunciation.name} id=${_card.id} '
            'expected="${_spec.expectedText}" heard="${result.displayText ?? ''}"',
      );
    } catch (error) {
      _flow = ReviewFlow.recorded;
      emitState(_buildState());
      rethrow;
    }
  }

  Future<void> _completeReview() async {
    if (_flow != ReviewFlow.reviewing) {
      return;
    }
    emitEvent(const TaskCompleted(TrainingOutcome.skipped));
  }

  Future<void> _startRecordingSoundWave() async {
    await _recordingLevelSubscription?.cancel();
    _soundWaveService.reset();
    _soundWaveService.start();
    _recordingLevelSubscription = _audioRecorder.amplitudeStream.listen(
      _soundWaveService.onSoundLevel,
    );
  }

  Future<void> _stopRecordingSoundWave() async {
    await _recordingLevelSubscription?.cancel();
    _recordingLevelSubscription = null;
    _soundWaveService.stop();
  }

  void _log(String message) {
    appLogD('speech', message);
  }
}
