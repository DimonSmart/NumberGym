import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../learning_language.dart';
import '../pronunciation_models.dart';
import '../services/audio_recorder_service.dart';
import '../services/azure_speech_service.dart';
import '../services/sound_wave_service.dart';
import '../task_runtime.dart';
import '../task_state.dart';
import '../tasks/phrase_pronunciation_task.dart';
import '../training_outcome.dart';

class PhrasePronunciationRuntime extends TaskRuntimeBase {
  PhrasePronunciationRuntime({
    required PhrasePronunciationTask task,
    required LearningLanguage language,
    required AudioRecorderServiceBase audioRecorder,
    required SoundWaveServiceBase soundWaveService,
    required AzureSpeechService azureSpeechService,
  })  : _task = task,
        _language = language,
        _audioRecorder = audioRecorder,
        _soundWaveService = soundWaveService,
        _azureSpeechService = azureSpeechService,
        super(
          PhrasePronunciationState(
            taskId: task.id,
            numberValue: task.numberValue,
            displayText: task.displayText,
            flow: PhraseFlow.waiting,
            hasRecording: false,
            result: null,
            isWaveVisible: false,
          ),
        );

  final PhrasePronunciationTask _task;
  final LearningLanguage _language;
  final AudioRecorderServiceBase _audioRecorder;
  final SoundWaveServiceBase _soundWaveService;
  final AzureSpeechService _azureSpeechService;

  StreamSubscription<double>? _recordingLevelSubscription;
  File? _recordingFile;
  PronunciationAnalysisResult? _result;
  PhraseFlow _flow = PhraseFlow.waiting;
  bool _disposed = false;

  @override
  Future<void> start() async {
    if (_disposed) return;
    emitState(_buildState());
  }

  @override
  Future<void> handleAction(TaskAction action) async {
    if (_disposed) return;
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
  Future<void> onTimerTimeout() async {
    // Phrase pronunciation does not use timer.
  }

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

  PhrasePronunciationState _buildState() {
    return PhrasePronunciationState(
      taskId: _task.id,
      numberValue: _task.numberValue,
      displayText: _task.displayText,
      flow: _flow,
      hasRecording: _recordingFile != null,
      result: _result,
      isWaveVisible: _flow == PhraseFlow.recording,
    );
  }

  Future<void> _startRecording() async {
    if (_flow == PhraseFlow.recording || _flow == PhraseFlow.sending) return;
    _recordingFile = null;
    _result = null;
    try {
      await _audioRecorder.start();
      _flow = PhraseFlow.recording;
      emitEvent(const TaskUserInteracted());
      await _startRecordingSoundWave();
      emitState(_buildState());
      _log('Pronunciation recording started.');
    } catch (error) {
      _flow = PhraseFlow.waiting;
      emitState(_buildState());
      emitEvent(TaskError('Cannot start recording: $error', shouldPause: false));
      _log('Pronunciation recording failed to start: $error');
    }
  }

  Future<void> _stopRecording() async {
    if (_flow != PhraseFlow.recording) return;
    try {
      final file = await _audioRecorder.stop();
      _recordingFile = file;
      _flow = file == null ? PhraseFlow.waiting : PhraseFlow.recorded;
      await _stopRecordingSoundWave();
      emitState(_buildState());
      if (file == null) {
        _log('Pronunciation recording stopped: file missing.');
      } else {
        final size = await file.length();
        _log('Pronunciation recording stopped: file="${file.path}" size=$size');
      }
    } catch (error) {
      _flow = PhraseFlow.waiting;
      await _stopRecordingSoundWave();
      emitState(_buildState());
      emitEvent(TaskError('Recording failed: $error', shouldPause: false));
      _log('Pronunciation recording failed to stop: $error');
    }
  }

  Future<void> _cancelRecording() async {
    if (_audioRecorder.isRecording) {
      await _audioRecorder.cancel();
    }
    await _stopRecordingSoundWave();
    _recordingFile = null;
    _result = null;
    _flow = PhraseFlow.waiting;
    emitState(_buildState());
  }

  Future<void> _sendRecording() async {
    final file = _recordingFile;
    if (file == null) {
      throw StateError('No recording to send');
    }
    if (_flow == PhraseFlow.sending) return;
    _flow = PhraseFlow.sending;
    emitState(_buildState());
    _log('Pronunciation send: starting.');
    try {
      final result = await _azureSpeechService.analyzePronunciation(
        audioFile: file,
        expectedText: _task.text,
        language: _language.locale,
      );
      _result = result;
      _flow = PhraseFlow.reviewing;
      emitState(_buildState());
      _log('Pronunciation send: completed, awaiting review.');
    } catch (error) {
      _flow = PhraseFlow.recorded;
      emitState(_buildState());
      _log('Pronunciation send failed: $error');
      rethrow;
    }
  }

  Future<void> _completeReview() async {
    if (_flow != PhraseFlow.reviewing) return;
    emitEvent(const TaskCompleted(TrainingOutcome.ignore));
  }

  Future<void> _startRecordingSoundWave() async {
    await _recordingLevelSubscription?.cancel();
    _soundWaveService.reset();
    _soundWaveService.start();
    _recordingLevelSubscription = _audioRecorder.amplitudeStream.listen(
      _soundWaveService.onSoundLevel,
      onError: (error) {
        _log('Recording sound level error: $error');
      },
    );
  }

  Future<void> _stopRecordingSoundWave() async {
    await _recordingLevelSubscription?.cancel();
    _recordingLevelSubscription = null;
    _soundWaveService.stop();
  }

  void _log(String message) {
    if (!kDebugMode) return;
    final now = DateTime.now().toString();
    final time = now.substring(11, 23);
    debugPrint('[$time] $message');
  }
}
