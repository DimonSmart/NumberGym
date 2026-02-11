import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/daily_session_stats.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/repositories.dart';
import 'package:number_gym/features/training/domain/services/audio_recorder_service.dart';
import 'package:number_gym/features/training/domain/services/azure_speech_service.dart';
import 'package:number_gym/features/training/domain/services/card_timer.dart';
import 'package:number_gym/features/training/domain/services/keep_awake_service.dart';
import 'package:number_gym/features/training/domain/services/sound_wave_service.dart';
import 'package:number_gym/features/training/domain/services/speech_service.dart';
import 'package:number_gym/features/training/domain/services/tts_service.dart';
import 'package:number_gym/features/training/domain/study_streak.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_services.dart';
import 'package:number_gym/features/training/domain/training_task.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

String repoStorageKey(TrainingItemId id, LearningLanguage language) {
  return '${language.code}:${id.storageKey}';
}

class InMemoryProgressRepository implements ProgressRepositoryBase {
  InMemoryProgressRepository({Map<String, CardProgress>? seeded}) {
    if (seeded != null) {
      _storage.addAll(seeded);
    }
  }

  final Map<String, CardProgress> _storage = <String, CardProgress>{};

  @override
  Future<Map<TrainingItemId, CardProgress>> loadAll(
    List<TrainingItemId> cardIds, {
    required LearningLanguage language,
  }) async {
    final result = <TrainingItemId, CardProgress>{};
    for (final id in cardIds) {
      result[id] = _storage[repoStorageKey(id, language)] ?? CardProgress.empty;
    }
    return result;
  }

  @override
  Future<void> save(
    TrainingItemId cardId,
    CardProgress progress, {
    required LearningLanguage language,
  }) async {
    _storage[repoStorageKey(cardId, language)] = progress;
  }

  @override
  Future<void> reset({required LearningLanguage language}) async {
    final prefix = '${language.code}:';
    _storage.removeWhere((key, _) => key.startsWith(prefix));
  }

  CardProgress read(TrainingItemId cardId, LearningLanguage language) {
    return _storage[repoStorageKey(cardId, language)] ?? CardProgress.empty;
  }
}

class FakeSettingsRepository implements SettingsRepositoryBase {
  FakeSettingsRepository({
    LearningLanguage language = LearningLanguage.english,
    bool premiumPronunciation = false,
    bool autoSimulationEnabled = false,
    int autoSimulationContinueCount = 0,
    int celebrationCounter = 0,
    LearningMethod? forcedMethod,
    TrainingItemType? forcedItemType,
    Map<LearningLanguage, DailySessionStats>? dailySessionStatsByLanguage,
    Map<LearningLanguage, StudyStreak>? streakByLanguage,
    Map<LearningLanguage, String?>? voiceByLanguage,
  }) : _language = language,
       _premium = premiumPronunciation,
       _autoSimulationEnabled = autoSimulationEnabled,
       _autoSimulationContinueCount = autoSimulationContinueCount,
       _celebrationCounter = celebrationCounter,
       _forcedMethod = forcedMethod,
       _forcedItemType = forcedItemType,
       _dailySessionStatsByLanguage =
           dailySessionStatsByLanguage ??
           <LearningLanguage, DailySessionStats>{},
       _streakByLanguage =
           streakByLanguage ?? <LearningLanguage, StudyStreak>{},
       _voiceByLanguage = voiceByLanguage ?? <LearningLanguage, String?>{};

  LearningLanguage _language;
  bool _premium;
  bool _autoSimulationEnabled;
  int _autoSimulationContinueCount;
  int _celebrationCounter;
  LearningMethod? _forcedMethod;
  TrainingItemType? _forcedItemType;
  final Map<LearningLanguage, DailySessionStats> _dailySessionStatsByLanguage;
  final Map<LearningLanguage, StudyStreak> _streakByLanguage;
  final Map<LearningLanguage, String?> _voiceByLanguage;

  @override
  LearningLanguage readLearningLanguage() => _language;

  @override
  Future<void> setLearningLanguage(LearningLanguage language) async {
    _language = language;
  }

  @override
  bool readPremiumPronunciationEnabled() => _premium;

  @override
  Future<void> setPremiumPronunciationEnabled(bool enabled) async {
    _premium = enabled;
  }

  @override
  bool readAutoSimulationEnabled() => _autoSimulationEnabled;

  @override
  Future<void> setAutoSimulationEnabled(bool enabled) async {
    _autoSimulationEnabled = enabled;
  }

  @override
  int readAutoSimulationContinueCount() => _autoSimulationContinueCount;

  @override
  Future<void> setAutoSimulationContinueCount(int count) async {
    _autoSimulationContinueCount = count;
  }

  @override
  int readCelebrationCounter() => _celebrationCounter;

  @override
  Future<void> setCelebrationCounter(int counter) async {
    _celebrationCounter = counter;
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
  String? readTtsVoiceId(LearningLanguage language) {
    return _voiceByLanguage[language];
  }

  @override
  Future<void> setTtsVoiceId(LearningLanguage language, String? voiceId) async {
    _voiceByLanguage[language] = voiceId;
  }

  @override
  LearningMethod? readDebugForcedLearningMethod() => _forcedMethod;

  @override
  Future<void> setDebugForcedLearningMethod(LearningMethod? method) async {
    _forcedMethod = method;
  }

  @override
  TrainingItemType? readDebugForcedItemType() => _forcedItemType;

  @override
  Future<void> setDebugForcedItemType(TrainingItemType? type) async {
    _forcedItemType = type;
  }
}

class FakeSpeechService implements SpeechServiceBase {
  FakeSpeechService({
    this.ready = true,
    this.errorMessage,
    List<stt.LocaleName>? locales,
  }) : _locales = locales ?? const <stt.LocaleName>[];

  final bool ready;
  final String? errorMessage;
  final List<stt.LocaleName> _locales;
  bool _isListening = false;

  @override
  List<stt.LocaleName> get locales => _locales;

  @override
  bool get isListening => _isListening;

  @override
  Future<SpeechInitResult> initialize({
    required void Function(SpeechRecognitionError p1) onError,
    required void Function(String p1) onStatus,
    bool requestPermission = true,
  }) async {
    return SpeechInitResult(
      ready: ready,
      errorMessage: errorMessage,
      locales: _locales,
    );
  }

  @override
  Future<void> listen({
    required void Function(SpeechRecognitionResult p1) onResult,
    required void Function(double p1) onSoundLevelChange,
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
  FakeTtsService({this.languageAvailable = true});

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
  final List<bool> calls = <bool>[];
  bool enabled = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
    calls.add(enabled);
  }

  @override
  void dispose() {
    enabled = false;
  }
}

class FakeSoundWaveService implements SoundWaveServiceBase {
  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();
  bool started = false;

  @override
  Stream<List<double>> get stream => _controller.stream;

  @override
  void start() {
    started = true;
  }

  @override
  void stop() {
    started = false;
  }

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
    internet: internet ?? () async => true,
  );
}
