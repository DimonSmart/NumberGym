import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/number_card.dart';
import 'repositories.dart';
import 'services/answer_matcher.dart';
import 'services/card_timer.dart';
import 'services/keep_awake_service.dart';
import 'services/sound_wave_service.dart';
import 'services/speech_service.dart';
import 'training_session.dart';
import 'training_state.dart';

export 'training_state.dart';

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
  SpeakNumberTask? get currentCard => _session.state.currentCard;
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
