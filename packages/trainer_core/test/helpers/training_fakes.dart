import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:trainer_core/trainer_core.dart';

class InMemoryProgressRepository implements ProgressRepositoryBase {
  final Map<String, CardProgress> _storage = <String, CardProgress>{};

  @override
  Future<Map<String, CardProgress>> loadAll(
    List<String> storageKeys, {
    required LearningLanguage language,
  }) async {
    final result = <String, CardProgress>{};
    for (final key in storageKeys) {
      result[key] = _storage[key] ?? CardProgress.empty;
    }
    return result;
  }

  @override
  Future<void> save(
    String storageKey,
    CardProgress progress, {
    required LearningLanguage language,
  }) async {
    _storage[storageKey] = progress;
  }

  @override
  Future<void> reset({required LearningLanguage language}) async {
    _storage.clear();
  }
}

class FakeSpeechService implements SpeechServiceBase {
  FakeSpeechService({this.ready = false});

  final bool ready;
  bool _isListening = false;

  @override
  List<stt.LocaleName> get locales => const <stt.LocaleName>[];

  @override
  bool get isListening => _isListening;

  @override
  Future<SpeechInitResult> initialize({
    required void Function(SpeechRecognitionError) onError,
    required void Function(String) onStatus,
    bool requestPermission = true,
  }) async {
    return SpeechInitResult(ready: ready);
  }

  @override
  Future<void> listen({
    required void Function(SpeechRecognitionResult) onResult,
    required void Function(double) onSoundLevelChange,
    required Duration listenFor,
    required Duration pauseFor,
    String? localeId,
    required stt.ListenMode listenMode,
    bool partialResults = true,
  }) async {
    _isListening = true;
  }

  @override
  Future<void> stop() async {
    _isListening = false;
  }

  @override
  void dispose() {
    _isListening = false;
  }
}

class FakeTtsService implements TtsServiceBase {
  FakeTtsService({this.languageAvailable = false});

  final bool languageAvailable;

  @override
  Future<bool> isLanguageAvailable(String locale) async => languageAvailable;

  @override
  Future<List<TtsVoice>> listVoices() async => const <TtsVoice>[];

  @override
  Future<void> setVoice(TtsVoice voice) async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class FakeCardTimer implements CardTimerBase {
  Duration _duration = Duration.zero;
  bool _running = false;
  void Function()? _onTimeout;

  @override
  Duration get duration => _duration;

  @override
  bool get isRunning => _running;

  @override
  void start(Duration duration, void Function() onTimeout) {
    _duration = duration;
    _running = true;
    _onTimeout = onTimeout;
  }

  @override
  Duration remaining() => _duration;

  @override
  void pause() {
    _running = false;
  }

  @override
  void resume() {
    if (_onTimeout != null) {
      _running = true;
    }
  }

  @override
  void stop() {
    _running = false;
    _onTimeout = null;
  }

  @override
  void dispose() {
    stop();
  }
}

class FakeKeepAwakeService implements KeepAwakeServiceBase {
  bool enabled = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
  }

  @override
  void dispose() {
    enabled = false;
  }
}

class FakeSoundWaveService implements SoundWaveServiceBase {
  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();

  @override
  Stream<List<double>> get stream => _controller.stream;

  @override
  void start() {}

  @override
  void stop() {}

  @override
  void reset() {
    if (!_controller.isClosed) {
      _controller.add(const <double>[]);
    }
  }

  @override
  void onSoundLevel(double level) {}

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}

class FakeAudioRecorderService implements AudioRecorderServiceBase {
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<void> start() async {
    _isRecording = true;
  }

  @override
  Future<File?> stop() async {
    _isRecording = false;
    return null;
  }

  @override
  Future<void> cancel() async {
    _isRecording = false;
  }

  @override
  void dispose() {
    unawaited(_amplitudeController.close());
  }
}

TrainingServices buildFakeTrainingServices({
  SpeechServiceBase? speech,
  SoundWaveServiceBase? soundWave,
  CardTimerBase? timer,
  KeepAwakeServiceBase? keepAwake,
  AudioRecorderServiceBase? audioRecorder,
  AzureSpeechService? azure,
  TtsServiceBase? tts,
  InternetChecker? internet,
}) {
  return TrainingServices(
    speech: speech ?? FakeSpeechService(),
    soundWave: soundWave ?? FakeSoundWaveService(),
    timer: timer ?? FakeCardTimer(),
    keepAwake: keepAwake ?? FakeKeepAwakeService(),
    audioRecorder: audioRecorder ?? FakeAudioRecorderService(),
    azure:
        azure ??
        AzureSpeechService(
          client: http.Client(),
          endpoint: Uri.parse('http://localhost:1/pronunciation/analyze'),
        ),
    tts: tts ?? FakeTtsService(),
    internet: internet ?? () async => false,
  );
}

class FakeSettingsRepository implements SettingsRepositoryBase {
  FakeSettingsRepository({
    LearningLanguage language = LearningLanguage.english,
    Map<LearningLanguage, DailySessionStats>? dailySessionStatsByLanguage,
    Map<LearningLanguage, StudyStreak>? streakByLanguage,
  }) : _language = language,
       _dailySessionStatsByLanguage =
           dailySessionStatsByLanguage ??
           <LearningLanguage, DailySessionStats>{},
       _streakByLanguage =
           streakByLanguage ?? <LearningLanguage, StudyStreak>{};

  LearningLanguage _language;
  final Map<LearningLanguage, DailySessionStats> _dailySessionStatsByLanguage;
  final Map<LearningLanguage, StudyStreak> _streakByLanguage;

  @override
  LearningLanguage readLearningLanguage() => _language;

  @override
  Future<void> setLearningLanguage(LearningLanguage language) async {
    _language = language;
  }

  @override
  DailySessionStats readDailySessionStats({DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final stats = _dailySessionStatsByLanguage[_language];
    if (stats == null) {
      return DailySessionStats.emptyFor(resolvedNow);
    }
    return stats.normalizedFor(resolvedNow);
  }

  @override
  Future<void> setDailySessionStats(DailySessionStats stats) async {
    _dailySessionStatsByLanguage[_language] = stats;
  }

  @override
  StudyStreak readStudyStreak() {
    return _streakByLanguage[_language] ?? StudyStreak.empty();
  }

  @override
  Future<void> setStudyStreak(StudyStreak streak) async {
    _streakByLanguage[_language] = streak;
  }

  @override
  bool readPremiumPronunciationEnabled() => false;

  @override
  Future<void> setPremiumPronunciationEnabled(bool enabled) async {}

  @override
  bool readAutoSimulationEnabled() => false;

  @override
  Future<void> setAutoSimulationEnabled(bool enabled) async {}

  @override
  int readAutoSimulationContinueCount() => 0;

  @override
  Future<void> setAutoSimulationContinueCount(int count) async {}

  @override
  int readCelebrationCounter() => 0;

  @override
  Future<void> setCelebrationCounter(int counter) async {}

  @override
  String? readTtsVoiceId(LearningLanguage language) => null;

  @override
  Future<void> setTtsVoiceId(LearningLanguage language, String? voiceId) async {}

  @override
  String? readDebugForcedMode() => null;

  @override
  Future<void> setDebugForcedMode(String? mode) async {}

  @override
  String? readDebugForcedFamilyKey() => null;

  @override
  Future<void> setDebugForcedFamilyKey(String? familyKey) async {}
}
