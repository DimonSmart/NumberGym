import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/number_card.dart';
import 'pronunciation_models.dart';
import 'number_words_task.dart';
import 'training_session.dart';
import 'training_task.dart';
import 'repositories.dart';
import 'services/answer_matcher.dart';
import 'services/card_timer.dart';
import 'services/keep_awake_service.dart';
import 'services/sound_wave_service.dart';
import 'services/speech_service.dart';
import 'training_state.dart';

export 'training_state.dart';
export 'training_session.dart' show TrainingOutcome;
export 'training_task.dart' show TrainingTaskKind;

class TrainingController extends ChangeNotifier {
  TrainingController({
    required SettingsRepositoryBase settingsRepository,
    required ProgressRepositoryBase progressRepository,
    stt.SpeechToText? speech,
    SpeechServiceBase? speechService,
    SoundWaveServiceBase? soundWaveService,
    AnswerMatcher? answerMatcher,
    CardTimerBase? cardTimer,
    KeepAwakeServiceBase? keepAwakeService,
  }) {
    _session = TrainingSession(
      settingsRepository: settingsRepository,
      progressRepository: progressRepository,
      speech: speech,
      speechService: speechService,
      soundWaveService: soundWaveService,
      answerMatcher: answerMatcher,
      cardTimer: cardTimer,
      keepAwakeService: keepAwakeService,
      onStateChanged: _notify,
    );
  }

  late final TrainingSession _session;
  bool _disposed = false;

  TrainingState get state => _session.state;
  TrainerStatus get status => _session.state.status;
  bool get speechReady => _session.state.speechReady;
  String? get errorMessage => _session.state.errorMessage;
  TrainingFeedback? get feedback => _session.state.feedback;
  String? get feedbackText => _session.state.feedback?.text;
  TrainingFeedbackType? get feedbackType => _session.state.feedback?.type;
  TrainingTask? get currentTask => _session.state.currentTask;
  TrainingTaskKind? get currentTaskKind => _session.state.currentTask?.kind;
  NumberPronunciationTask? get currentCard => _session.state.currentCard;
  NumberReadingTask? get currentNumberReadingTask {
    final task = _session.state.currentTask;
    return task is NumberReadingTask ? task : null;
  }
  String get displayText => _session.state.displayText;
  bool get isAwaitingRecording => _session.state.isAwaitingRecording;
  bool get isRecording => _session.state.isRecording;
  bool get hasRecording => _session.state.hasRecording;
  bool get isAwaitingPronunciationReview =>
      _session.state.isAwaitingPronunciationReview;
  PronunciationAnalysisResult? get pronunciationResult =>
      _session.state.pronunciationResult;
  String? get hintText => _session.state.hintText;
  List<String> get expectedTokens => _session.state.expectedTokens;
  List<bool> get matchedTokens => _session.state.matchedTokens;

  Stream<List<double>> get soundStream => _session.soundStream;

  Duration get currentCardDuration => _session.state.cardDuration;
  bool get isTimerRunning => _session.state.isTimerRunning;

  int get totalCards => _session.totalCards;
  int get learnedCount => _session.learnedCount;
  int get remainingCount => _session.remainingCount;
  bool get hasRemainingCards => _session.hasRemainingCards;

  Future<void> initialize() => _session.initialize();
  Future<void> retryInitSpeech() => _session.retryInitSpeech();
  Future<void> startTraining() => _session.startTraining();
  Future<void> stopTraining() => _session.stopTraining();
  Future<void> pauseForOverlay() => _session.pauseForOverlay();
  Future<void> restoreAfterOverlay() => _session.restoreAfterOverlay();

  Future<void> setPremiumPronunciationEnabled(bool enabled) =>
      _session.setPremiumPronunciationEnabled(enabled);

  Future<PronunciationAnalysisResult> analyzePronunciationRecording(
    File audioFile,
  ) =>
      _session.analyzePronunciationRecording(audioFile);

  Future<void> answerNumberReading(String option) =>
      _session.answerNumberReading(option);

  Future<void> startPronunciationRecording() =>
      _session.startPronunciationRecording();

  Future<void> stopPronunciationRecording() =>
      _session.stopPronunciationRecording();

  Future<void> cancelPronunciationRecording() =>
      _session.cancelPronunciationRecording();

  Future<PronunciationAnalysisResult> sendPronunciationRecording({File? file}) =>
      _session.sendPronunciationRecording(file: file);

  Future<void> completePronunciationReview() =>
      _session.completePronunciationReview();

  Future<void> completeCurrentTaskWithOutcome(TrainingOutcome outcome) =>
      _session.completeCurrentTaskWithOutcome(outcome);

  @override
  void dispose() {
    _disposed = true;
    _session.dispose();
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
