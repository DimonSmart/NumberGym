import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/card_progress.dart';
import '../data/number_card.dart';
import '../data/number_cards.dart';
import '../data/progress_repository.dart';
import '../data/settings_repository.dart';
import 'learning_language.dart';

enum TrainerStatus { idle, running, paused, finished }

class TrainingController extends ChangeNotifier {
  TrainingController({
    required Box<String> settingsBox,
    required Box<CardProgress> progressBox,
    required TickerProvider vsync,
    stt.SpeechToText? speech,
  })  : _settingsRepository = SettingsRepository(settingsBox),
        _progressRepository = ProgressRepository(progressBox),
        _speech = speech ?? stt.SpeechToText(),
        _timerController = AnimationController(vsync: vsync) {
    final initialDuration = Duration(
      seconds: _settingsRepository.readAnswerDurationSeconds(),
    );
    _timerController
      ..duration = initialDuration
      ..addStatusListener(_onTimerStatus);

    final cards = buildNumberCards();
    _cardsById = {for (final card in cards) card.id: card};
    _cardIds = _cardsById.keys.toList()..sort();
  }

  final Random _random = Random();
  final stt.SpeechToText _speech;
  final ProgressRepository _progressRepository;
  final SettingsRepository _settingsRepository;
  final AnimationController _timerController;

  late final Map<int, NumberCard> _cardsById;
  late final List<int> _cardIds;

  List<stt.LocaleName> _locales = const [];
  Map<int, CardProgress> _progressById = {};
  List<int> _pool = [];

  TrainerStatus _status = TrainerStatus.idle;
  bool _speechReady = false;
  String? _errorMessage;

  int _attemptCounter = 0;
  int? _activeAttemptId;
  int? _currentCardId;
  int? _currentPoolIndex;
  NumberCard? _currentCard;
  int _consecutiveSilentCards = 0;
  int _consecutiveClientErrors = 0;
  bool _cardActive = false;
  bool _heardSpeechThisCard = false;

  List<String> _expectedTokens = const [];
  List<bool> _matchedTokens = const [];
  int _matchedTokenCount = 0;
  Set<String> _acceptedAnswers = {};
  String _lastPartialResult = '';
  static const Duration _listenRestartDelay = Duration(milliseconds: 500);
  static const int _maxConsecutiveClientErrors = 3;

  String? _feedbackText;
  Color? _feedbackColor;
  Timer? _feedbackTimer;
  bool _keepAwake = false;
  static const int _soundHistoryLength = 32;
  final List<double> _soundHistory =
      List<double>.filled(_soundHistoryLength, 0.0, growable: true);
  double _minSoundLevel = 999;
  double _maxSoundLevel = -999;
  static const Duration _soundHistoryTick = Duration(milliseconds: 80);
  static const double _soundSmoothing = 0.35;
  static const double _soundRangeFloor = 12.0;
  static const double _soundNoiseFloor = 0.18;
  static const double _soundResponseCurve = 1.6;
  static const double _soundGain = 1.15;
  Timer? _soundWaveTimer;
  double _lastNormalizedSound = 0.0;
  double _smoothedSound = 0.0;
  bool _forceDefaultLocale = false;
  bool _suppressNextClientError = false;

  bool _disposed = false;

  TrainerStatus get status => _status;
  bool get speechReady => _speechReady;
  String? get errorMessage => _errorMessage;
  String? get feedbackText => _feedbackText;
  Color? get feedbackColor => _feedbackColor;
  List<double> get soundHistory => _soundHistory;
  NumberCard? get currentCard => _currentCard;
  List<String> get expectedTokens => _expectedTokens;
  List<bool> get matchedTokens => _matchedTokens;
  AnimationController get timerController => _timerController;
  int get totalCards => _cardsById.length;
  int get learnedCount =>
      _progressById.values.where((progress) => progress.learned).length;
  int get remainingCount => totalCards - learnedCount;
  bool get hasRemainingCards => _pool.isNotEmpty;

  Future<void> initialize() async {
    await _loadProgress();
    await _initSpeech();
    _notify();
  }

  Future<void> retryInitSpeech() async {
    await _initSpeech();
    _notify();
  }

  Future<void> startTraining() async {
    if (_status == TrainerStatus.running) return;
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        _notify();
        return;
      }
    }

    if (_pool.isEmpty) {
      _status = TrainerStatus.finished;
      unawaited(_setKeepAwake(false));
      _notify();
      return;
    }

    _errorMessage = null;
    _status = TrainerStatus.running;
    _consecutiveSilentCards = 0;
    _consecutiveClientErrors = 0;
    _forceDefaultLocale = false;
    _suppressNextClientError = false;
    _notify();
    unawaited(_setKeepAwake(true));
    await _startNextCard();
  }

  Future<void> stopTraining() async {
    _feedbackTimer?.cancel();
    await _stopAttempt();
    _resetSoundLevels();
    _forceDefaultLocale = false;
    _suppressNextClientError = false;
    _status = TrainerStatus.idle;
    _errorMessage = null;
    _currentCard = null;
    _currentCardId = null;
    _currentPoolIndex = null;
    _consecutiveSilentCards = 0;
    _consecutiveClientErrors = 0;
    _heardSpeechThisCard = false;
    _expectedTokens = const [];
    _matchedTokens = const [];
    _matchedTokenCount = 0;
    _acceptedAnswers = {};
    _feedbackText = null;
    _feedbackColor = null;
    _lastPartialResult = '';
    _notify();
    unawaited(_setKeepAwake(false));
  }

  Future<void> pauseForOverlay() async {
    await _stopAttempt();
    _status = TrainerStatus.idle;
    await _setKeepAwake(false);
    _notify();
  }

  Future<void> restoreAfterOverlay() async {
    await _loadProgress();
    _currentCard = null;
    _currentCardId = null;
    _currentPoolIndex = null;
    _consecutiveSilentCards = 0;
    _heardSpeechThisCard = false;
    _forceDefaultLocale = false;
    _expectedTokens = const [];
    _matchedTokens = const [];
    _matchedTokenCount = 0;
    _acceptedAnswers = {};
    _status = TrainerStatus.idle;
    await _setKeepAwake(false);
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _log(String message) {
    final now = DateTime.now().toString();
    final time = now.substring(11, 23);
    debugPrint('[$time] $message');
  }

  @override
  void dispose() {
    _disposed = true;
    _feedbackTimer?.cancel();
    _stopSoundWaveTicker();
    _timerController.dispose();
    unawaited(_speech.stop());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  Future<void> _loadProgress() async {
    if (_cardIds.isEmpty) {
      _progressById = {};
      _pool = [];
      return;
    }
    final maxCardId = _cardIds.last;
    final progress = await _progressRepository.loadAll(maxCardId: maxCardId);
    _progressById = {
      for (final id in _cardIds) id: progress[id] ?? CardProgress.empty,
    };
    _pool = [
      for (final id in _cardIds)
        if (!(_progressById[id]?.learned ?? false)) id,
    ]..shuffle(_random);
  }

  Future<void> _initSpeech() async {
    _errorMessage = null;
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _speechReady = false;
      _errorMessage =
          'Microphone permission is required. Enable it in system settings.';
      return;
    }

    final available = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );

    if (!available) {
      _speechReady = false;
      _errorMessage = 'Speech recognition is not available on this device.';
      return;
    }

    _locales = await _speech.locales();
    _speechReady = true;
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _log(
      'Speech error: "${error.errorMsg}", permanent: ${error.permanent}',
    );
    if (_isLanguageUnavailableError(error) && !_forceDefaultLocale) {
      _forceDefaultLocale = true;
      _log(
        'Speech language unavailable. Falling back to system default locale.',
      );
      unawaited(_restartListeningAfterLocaleFallback());
      return;
    }
    final isAttemptError =
        _isSpeechTimeoutError(error) || _isNoMatchError(error);
    if (_isClientError(error)) {
      if (_suppressNextClientError) {
        _suppressNextClientError = false;
        return;
      }
      _consecutiveClientErrors += 1;
      final shouldPause =
          _consecutiveClientErrors >= _maxConsecutiveClientErrors;
      if (shouldPause) {
        _errorMessage = 'Speech recognition stopped. Tap Start to try again.';
        if (_status == TrainerStatus.running) {
          _status = TrainerStatus.paused;
        }
        _notify();
        unawaited(_setKeepAwake(false));
        unawaited(_stopAttempt());
        return;
      }
      if (_status == TrainerStatus.running && _activeAttemptId != null) {
        unawaited(
          _handleAttemptResult(
            recognizedText: '',
          ),
        );
      }
      return;
    }
    _consecutiveClientErrors = 0;
    if (isAttemptError) {
      if (_status == TrainerStatus.running && _cardActive) {
        _suppressNextClientError = true;
      }
      if (_status == TrainerStatus.running && _activeAttemptId != null) {
        unawaited(
          _handleAttemptResult(
            recognizedText: '',
          ),
        );
      }
      return;
    }

    _errorMessage = _friendlySpeechError(error);
    if (_status == TrainerStatus.running) {
      _status = TrainerStatus.paused;
    }
    _notify();
    unawaited(_setKeepAwake(false));
    unawaited(_stopAttempt());
  }

  void _onSpeechStatus(String status) {
    _log('Speech status: $status');
    if (_status != TrainerStatus.running || !_cardActive) return;

    if (status == 'listening') {
      if (!_timerController.isAnimating) {
        _timerController.forward();
      }
    } else if (status == 'notListening' || status == 'done') {
      if (_timerController.isAnimating) {
        _timerController.stop();
      }
    }
  }

  Future<void> _restartListeningAfterLocaleFallback() async {
    if (_status != TrainerStatus.running || !_cardActive) return;
    _suppressNextClientError = false;
    _activeAttemptId = null;
    if (_speech.isListening) {
      await _speech.stop();
    }
    await Future.delayed(_listenRestartDelay);
    await _startListening();
  }

  LearningLanguage _currentLanguage() {
    return _settingsRepository.readLearningLanguage();
  }

  String? _resolveLocaleId(LearningLanguage language) {
    if (_forceDefaultLocale) return null;
    final prefix = language.localePrefix.toLowerCase();
    for (final locale in _locales) {
      if (locale.localeId.toLowerCase().startsWith(prefix)) {
        return locale.localeId;
      }
    }
    return null;
  }

  // TODO: Tune duration per prompt if needed.
  Duration _resolveCardDuration(String prompt) {
    final seconds = _settingsRepository.readAnswerDurationSeconds();
    return Duration(seconds: seconds);
  }

  stt.ListenMode _resolveListenMode() {
    if (_expectedTokens.length <= 2) {
      return stt.ListenMode.search;
    }
    return stt.ListenMode.dictation;
  }

  void _resetSoundLevels() {
    _minSoundLevel = 999;
    _maxSoundLevel = -999;
    _lastNormalizedSound = 0.0;
    _smoothedSound = 0.0;
    for (var i = 0; i < _soundHistory.length; i++) {
      _soundHistory[i] = 0.0;
    }
  }

  void _pushSoundSample(double normalized) {
    if (_soundHistory.isEmpty) {
      return;
    }
    _soundHistory.removeAt(0);
    _soundHistory.add(normalized);
    _notify();
  }

  void _startSoundWaveTicker() {
    if (_soundWaveTimer != null) return;
    _soundWaveTimer = Timer.periodic(_soundHistoryTick, (_) {
      if (_status != TrainerStatus.running || !_cardActive) {
        return;
      }
      _smoothedSound += (_lastNormalizedSound - _smoothedSound) * _soundSmoothing;
      _pushSoundSample(_smoothedSound);
    });
  }

  void _stopSoundWaveTicker() {
    _soundWaveTimer?.cancel();
    _soundWaveTimer = null;
  }

  double _applyNoiseGate(double normalized) {
    if (normalized <= _soundNoiseFloor) {
      return 0.0;
    }
    final adjusted = (normalized - _soundNoiseFloor) / (1 - _soundNoiseFloor);
    final shaped = pow(adjusted, _soundResponseCurve).toDouble();
    return (shaped * _soundGain).clamp(0.0, 1.0).toDouble();
  }

  double _normalizeSoundLevel(double level) {
    _minSoundLevel = min(_minSoundLevel, level);
    _maxSoundLevel = max(_maxSoundLevel, level);
    final range = (_maxSoundLevel - _minSoundLevel).abs();
    if (range >= _soundRangeFloor) {
      return ((level - _minSoundLevel) / range).clamp(0.0, 1.0).toDouble();
    }
    if (range >= 1e-3) {
      return ((level - _minSoundLevel) / _soundRangeFloor)
          .clamp(0.0, 1.0)
          .toDouble();
    }
    if (level < 0) {
      return ((level + 60) / 60).clamp(0.0, 1.0).toDouble();
    }
    return (level / 10).clamp(0.0, 1.0).toDouble();
  }

  void _onSoundLevel(double level) {
    if (_status != TrainerStatus.running || !_cardActive) {
      return;
    }
    final rawNormalized = _normalizeSoundLevel(level);
    final normalized = _applyNoiseGate(rawNormalized);

    _lastNormalizedSound = normalized;
    if (_soundWaveTimer == null) {
      _pushSoundSample(normalized);
    }
  }

  List<String> _tokenize(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    return trimmed.split(RegExp(r'\s+'));
  }

  String _normalizeAnswer(String text) {
    final trimmed = text.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    final withoutDiacritics = _stripDiacritics(trimmed);
    final cleaned =
        withoutDiacritics.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _stripDiacritics(String input) {
    return input
        .replaceAll('\u00e1', 'a')
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00ed', 'i')
        .replaceAll('\u00f3', 'o')
        .replaceAll('\u00fa', 'u')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00f1', 'n');
  }

  void _resetCardProgress(NumberCard? card) {
    final prompt = card?.prompt ?? '';
    _expectedTokens = _tokenize(prompt);
    _matchedTokens = List<bool>.filled(_expectedTokens.length, false);
    _matchedTokenCount = 0;
    final language = _currentLanguage();
    final answers = card?.answersFor(language) ?? const <String>[];
    final normalized = <String>{
      for (final answer in answers) _normalizeAnswer(answer),
      if (prompt.isNotEmpty) _normalizeAnswer(prompt),
    }..removeWhere((value) => value.isEmpty);
    _acceptedAnswers = normalized;
    if (prompt.isNotEmpty) {
      _log(
        'Speech expected: "$prompt" (lang: ${language.code}, answers: ${answers.join(", ")})',
      );
    }
  }

  int _firstUnmatchedIndex(String token) {
    for (var i = 0; i < _expectedTokens.length; i++) {
      if (!_matchedTokens[i] && _expectedTokens[i] == token) {
        return i;
      }
    }
    return -1;
  }

  bool _applyRecognition(List<String> recognizedTokens, String normalizedText) {
    if (normalizedText.isEmpty || _expectedTokens.isEmpty) {
      return false;
    }
    if (_acceptedAnswers.contains(normalizedText)) {
      if (_matchedTokenCount != _expectedTokens.length) {
        _matchedTokens = List<bool>.filled(_expectedTokens.length, true);
        _matchedTokenCount = _expectedTokens.length;
      }
      return true;
    }
    if (recognizedTokens.isEmpty) {
      return false;
    }

    var matchedAny = false;
    for (final token in recognizedTokens) {
      final index = _firstUnmatchedIndex(token);
      if (index != -1) {
        _matchedTokens[index] = true;
        _matchedTokenCount += 1;
        matchedAny = true;
      }
    }
    return matchedAny;
  }

  bool get _isCardComplete {
    return _expectedTokens.isNotEmpty &&
        _matchedTokenCount == _expectedTokens.length;
  }

  Duration _remainingCardDuration() {
    final total = _timerController.duration;
    if (total == null || total == Duration.zero) {
      return Duration.zero;
    }
    final remainingMicros =
        (total.inMicroseconds * (1 - _timerController.value)).round();
    return Duration(microseconds: max(0, remainingMicros));
  }

  Future<void> _startNextCard() async {
    if (_status != TrainerStatus.running) return;
    if (_pool.isEmpty) {
      _status = TrainerStatus.finished;
      unawaited(_setKeepAwake(false));
      _notify();
      return;
    }

    final poolIndex = _random.nextInt(_pool.length);
    _currentPoolIndex = poolIndex;
    _currentCardId = _pool[poolIndex];
    _currentCard = _cardsById[_currentCardId];
    _cardActive = true;
    _heardSpeechThisCard = false;
    _resetCardProgress(_currentCard);
    _resetSoundLevels();
    _suppressNextClientError = false;

    final prompt = _currentCard?.prompt ?? '';
    final duration = _resolveCardDuration(prompt);
    _timerController.stop();
    _timerController.duration = duration;
    _timerController.reset();

    _notify();
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_currentCardId == null ||
        _status != TrainerStatus.running ||
        !_cardActive) {
      return;
    }
    final remaining = _remainingCardDuration();
    if (remaining < const Duration(milliseconds: 500)) {
      unawaited(_completeCard(isCorrect: false, timeout: true));
      return;
    }
    final attemptId = ++_attemptCounter;
    _activeAttemptId = attemptId;
    _lastPartialResult = '';
    _suppressNextClientError = false;

    final language = _currentLanguage();
    final localeId = _resolveLocaleId(language);
    final listenMode = _resolveListenMode();
    _log(
      'Speech listen: remaining=${remaining.inMilliseconds}ms '
      'locale=${localeId ?? "system"} mode=$listenMode',
    );
    _startSoundWaveTicker();

    try {
      await _speech.listen(
        onResult: (result) => _onSpeechResult(result, attemptId),
        onSoundLevelChange: _onSoundLevel,
        listenFor: remaining,
        pauseFor: remaining,
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          listenMode: listenMode,
          partialResults: true,
        ),
      );
      _log('Speech listen started: isListening=${_speech.isListening}');
    } catch (error) {
      _errorMessage = 'Speech recognition failed to start.';
      _status = TrainerStatus.paused;
      _notify();
      await _stopAttempt();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result, int attemptId) {
    if (_activeAttemptId != attemptId) return;
    _consecutiveClientErrors = 0;
    final recognizedWords = result.recognizedWords;
    if (recognizedWords.trim().isNotEmpty) {
      _heardSpeechThisCard = true;
    }
    if (!result.finalResult) {
      if (recognizedWords.trim().isNotEmpty &&
          recognizedWords != _lastPartialResult) {
        _lastPartialResult = recognizedWords;
        _log('Speech partial: "$recognizedWords"');
      }
      return;
    }
    final resolvedWords = recognizedWords.trim().isEmpty
        ? _lastPartialResult
        : recognizedWords;
    _lastPartialResult = '';
    unawaited(
      _handleAttemptResult(recognizedText: resolvedWords),
    );
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_status != TrainerStatus.running || !_cardActive) return;
    unawaited(_completeCard(isCorrect: false, timeout: true));
  }

  Future<void> _handleAttemptResult({
    required String recognizedText,
  }) async {
    var resolvedText = recognizedText;
    if (resolvedText.trim().isEmpty && _lastPartialResult.isNotEmpty) {
      resolvedText = _lastPartialResult;
    }
    _lastPartialResult = '';
    _log('Speech recognized: "$resolvedText"');
    if (resolvedText.trim().isNotEmpty) {
      _heardSpeechThisCard = true;
    }
    final attemptId = _activeAttemptId;
    if (attemptId == null) return;
    _activeAttemptId = null;
    if (_speech.isListening) {
      await _speech.stop();
    }

    final normalizedText = _normalizeAnswer(resolvedText);
    final normalizedTokens = _tokenize(normalizedText);

    final didMatch = _applyRecognition(normalizedTokens, normalizedText);
    if (didMatch) {
      _notify();
    }

    if (_isCardComplete) {
      await _completeCard(isCorrect: true, timeout: false);
      return;
    }

    if (_timerController.status == AnimationStatus.completed ||
        _remainingCardDuration() <= Duration.zero) {
      await _completeCard(isCorrect: false, timeout: true);
      return;
    }

    if (_status != TrainerStatus.running) return;
    await Future.delayed(_listenRestartDelay);
    await _startListening();
  }

  Future<void> _completeCard({
    required bool isCorrect,
    required bool timeout,
  }) async {
    if (!_cardActive || _currentCardId == null) return;
    _cardActive = false;
    _activeAttemptId = null;
    _timerController.stop();
    _stopSoundWaveTicker();
    await _speech.stop();

    await _updateProgress(isCorrect: isCorrect);
    _showFeedback(isCorrect, timeout: timeout);

    if (_status == TrainerStatus.running) {
      if (_heardSpeechThisCard) {
        _consecutiveSilentCards = 0;
      } else {
        _consecutiveSilentCards += 1;
      }
      if (_consecutiveSilentCards >= 3) {
        await _pauseTraining();
        return;
      }
    }

    await _startNextCard();
  }

  Future<void> _updateProgress({required bool isCorrect}) async {
    final cardId = _currentCardId;
    if (cardId == null) return;
    final progress = _progressById[cardId] ?? CardProgress.empty;
    final attempts = List<bool>.from(progress.lastAttempts)..add(isCorrect);
    if (attempts.length > 10) {
      attempts.removeRange(0, attempts.length - 10);
    }
    final learned = attempts.length == 10 && attempts.every((value) => value);
    final updated = progress.copyWith(
      learned: learned,
      lastAttempts: attempts,
      totalAttempts: progress.totalAttempts + 1,
      totalCorrect: progress.totalCorrect + (isCorrect ? 1 : 0),
    );
    _progressById[cardId] = updated;
    await _progressRepository.save(cardId, updated);
    if (learned) {
      _removeFromPool();
    }
    _notify();
  }

  void _removeFromPool() {
    final index = _currentPoolIndex;
    if (index == null || index >= _pool.length) return;
    final lastIndex = _pool.length - 1;
    _pool[index] = _pool[lastIndex];
    _pool.removeLast();
    _currentPoolIndex = null;
    if (_pool.isEmpty) {
      _status = TrainerStatus.finished;
      unawaited(_setKeepAwake(false));
    }
  }

  void _showFeedback(
    bool isCorrect, {
    required bool timeout,
  }) {
    _feedbackTimer?.cancel();
    final text = isCorrect
        ? 'Correct'
        : timeout
            ? 'Timeout'
            : 'Wrong';
    final color = isCorrect ? Colors.green.shade700 : Colors.red.shade700;
    _feedbackText = text;
    _feedbackColor = color;
    _notify();

    _feedbackTimer = Timer(const Duration(seconds: 3), () {
      _feedbackText = null;
      _feedbackColor = null;
      _notify();
    });
  }

  Future<void> _pauseTraining() async {
    await _stopAttempt();
    _status = TrainerStatus.paused;
    _notify();
    unawaited(_setKeepAwake(false));
  }

  Future<void> _stopAttempt() async {
    _activeAttemptId = null;
    _cardActive = false;
    _stopSoundWaveTicker();
    _timerController
      ..stop()
      ..reset();
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  bool _isNoMatchError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase().trim();
    return code == 'error_no_match' || code.contains('no_match');
  }

  bool _isSpeechTimeoutError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase().trim();
    return code == 'error_speech_timeout' ||
        code == 'error_speach_timeout' ||
        code.contains('speech_timeout') ||
        code.contains('speach_timeout');
  }

  bool _isClientError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase().trim();
    return code == 'error_client' || code.contains('client');
  }

  bool _isLanguageUnavailableError(SpeechRecognitionError error) {
    final code = error.errorMsg.toLowerCase().trim();
    return code == 'error_language_unavailable' ||
        code.contains('language_unavailable');
  }

  String _friendlySpeechError(SpeechRecognitionError error) {
    final message = error.errorMsg.trim();
    if (message.isEmpty) {
      return 'Speech recognition error.';
    }
    if (_isLanguageUnavailableError(error)) {
      return 'Selected language is not available on this device.';
    }
    if (_isSpeechTimeoutError(error)) {
      return 'No speech detected (timeout).';
    }
    if (_isNoMatchError(error)) {
      return 'Could not match speech.';
    }
    return 'Speech recognition error: $message';
  }

  Future<void> _setKeepAwake(bool enabled) async {
    if (_keepAwake == enabled) return;
    _keepAwake = enabled;
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }
}
