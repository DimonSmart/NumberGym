import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:trainer_core/trainer_core.dart';

import 'helpers/training_fakes.dart';

const _moduleId = 'test';

final _testFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'test_family',
  label: 'Test',
  shortLabel: 'Test',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.speak],
);

ExerciseCard _buildCard({
  String promptText = '7',
  List<String> acceptedAnswers = const <String>['seven', '7'],
}) {
  return ExerciseCard(
    id: const ExerciseId(
      moduleId: _moduleId,
      familyId: 'test_family',
      variantId: '7',
    ),
    family: _testFamily,
    language: LearningLanguage.english,
    displayText: '7',
    promptText: promptText,
    acceptedAnswers: acceptedAnswers,
    celebrationText: '7 -> seven',
  );
}

BaseLanguageProfile _buildProfile() {
  return const BaseLanguageProfile(
    language: LearningLanguage.english,
    code: 'en',
    label: 'English',
    locale: 'en-US',
    textDirection: TextDirection.ltr,
    ttsPreviewText: 'test',
    preferredSpeechLocaleId: null,
    normalizer: _identityNormalizer,
  );
}

String _identityNormalizer(String text) => text.toLowerCase();

class _SimpleTokenizer implements MatcherTokenizer {
  @override
  List<MatchingToken> tokenize(String text) => [
    MatchingToken(display: text, normalized: text.toLowerCase()),
  ];
}

class _ControllableSpeechService implements SpeechServiceBase {
  void Function(SpeechRecognitionResult result)? _onResult;
  bool _isListening = false;

  int listenCallCount = 0;
  int stopCallCount = 0;
  int cancelCallCount = 0;
  bool clearListeningWhenCancelStarts = true;
  Completer<void>? cancelCompleter;

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
    return const SpeechInitResult(ready: true);
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
    _onResult = onResult;
    _isListening = true;
    listenCallCount += 1;
  }

  @override
  Future<void> stop() async {
    stopCallCount += 1;
    _isListening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount += 1;
    if (clearListeningWhenCancelStarts) {
      _isListening = false;
    }
    final completer = cancelCompleter;
    if (completer != null) {
      await completer.future;
    }
    _isListening = false;
  }

  @override
  void dispose() {
    _isListening = false;
  }

  Future<void> emitPartial(String text) async {
    _onResult?.call(
      SpeechRecognitionResult(<SpeechRecognitionWords>[
        SpeechRecognitionWords(
          text,
          null,
          SpeechRecognitionWords.missingConfidence,
        ),
      ], false),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> emitFinal(String text) async {
    _onResult?.call(
      SpeechRecognitionResult(<SpeechRecognitionWords>[
        SpeechRecognitionWords(
          text,
          null,
          SpeechRecognitionWords.missingConfidence,
        ),
      ], true),
    );
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('pause keeps remaining time and resume restarts listening', () async {
    final speech = FakeSpeechService(ready: true);
    final timer = FakeCardTimer();
    final runtime = SpeakRuntime(
      card: _buildCard(),
      profile: _buildProfile(),
      tokenizer: _SimpleTokenizer(),
      speechService: speech,
      soundWaveService: FakeSoundWaveService(),
      cardTimer: timer,
      cardDuration: const Duration(seconds: 15),
      hintText: null,
    );

    await runtime.start();

    expect(runtime.state.timer.isRunning, isTrue);
    expect(speech.isListening, isTrue);

    await runtime.handleAction(const PauseTaskAction());

    final pausedState = runtime.state as SpeakState;
    expect(pausedState.timer.isRunning, isFalse);
    expect(pausedState.timer.remaining, const Duration(seconds: 15));
    expect(pausedState.isListening, isFalse);
    expect(speech.isListening, isFalse);

    await runtime.handleAction(const ResumeTaskAction());

    final resumedState = runtime.state as SpeakState;
    expect(resumedState.timer.isRunning, isTrue);
    expect(speech.isListening, isTrue);

    await runtime.dispose();
  });

  test('prefers stronger partial over truncated final result', () async {
    final speech = _ControllableSpeechService();
    final runtime = SpeakRuntime(
      card: _buildCard(
        promptText: 'half past ten',
        acceptedAnswers: const <String>['half past ten', '10:30'],
      ),
      profile: _buildProfile(),
      tokenizer: _SimpleTokenizer(),
      speechService: speech,
      soundWaveService: FakeSoundWaveService(),
      cardTimer: FakeCardTimer(),
      cardDuration: const Duration(seconds: 15),
      hintText: null,
    );

    final completion = Completer<TaskCompleted>();
    final subscription = runtime.events.listen((event) {
      if (event is TaskCompleted && !completion.isCompleted) {
        completion.complete(event);
      }
    });

    await runtime.start();
    await speech.emitPartial('half past ten');
    await speech.emitFinal('10');

    final event = await completion.future.timeout(const Duration(seconds: 1));
    expect(event.outcome, TrainingOutcome.correct);
    expect(speech.listenCallCount, 1);

    await subscription.cancel();
    await runtime.dispose();
  });

  test('partial correct completes before cancel finishes', () async {
    final cancelCompleter = Completer<void>();
    final speech = _ControllableSpeechService()
      ..cancelCompleter = cancelCompleter
      ..clearListeningWhenCancelStarts = false;
    final runtime = SpeakRuntime(
      card: _buildCard(
        promptText: 'half past ten',
        acceptedAnswers: const <String>['half past ten', '10:30'],
      ),
      profile: _buildProfile(),
      tokenizer: _SimpleTokenizer(),
      speechService: speech,
      soundWaveService: FakeSoundWaveService(),
      cardTimer: FakeCardTimer(),
      cardDuration: const Duration(seconds: 15),
      hintText: null,
    );

    final completion = Completer<TaskCompleted>();
    final subscription = runtime.events.listen((event) {
      if (event is TaskCompleted && !completion.isCompleted) {
        completion.complete(event);
      }
    });

    await runtime.start();
    await speech.emitPartial('half past ten');

    final event = await completion.future.timeout(const Duration(seconds: 1));
    expect(event.outcome, TrainingOutcome.correct);
    expect(speech.cancelCallCount, 1);
    expect(speech.stopCallCount, 0);
    expect(speech.isListening, isTrue);

    await subscription.cancel();
    await runtime.dispose().timeout(const Duration(milliseconds: 100));
    expect(speech.isListening, isTrue);

    cancelCompleter.complete();
    await Future<void>.delayed(Duration.zero);
    expect(speech.isListening, isFalse);
  });

  test('late final after accepted partial is ignored', () async {
    final cancelCompleter = Completer<void>();
    final speech = _ControllableSpeechService()
      ..cancelCompleter = cancelCompleter;
    final runtime = SpeakRuntime(
      card: _buildCard(),
      profile: _buildProfile(),
      tokenizer: _SimpleTokenizer(),
      speechService: speech,
      soundWaveService: FakeSoundWaveService(),
      cardTimer: FakeCardTimer(),
      cardDuration: const Duration(seconds: 15),
      hintText: null,
    );

    final events = <TaskCompleted>[];
    final completion = Completer<void>();
    final subscription = runtime.events.listen((event) {
      if (event is TaskCompleted) {
        events.add(event);
        if (!completion.isCompleted) {
          completion.complete();
        }
      }
    });

    await runtime.start();
    await speech.emitPartial('seven');
    await completion.future.timeout(const Duration(seconds: 1));
    await speech.emitFinal('7');
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.outcome, TrainingOutcome.correct);

    cancelCompleter.complete();
    await subscription.cancel();
    await runtime.dispose();
  });

  test('final correct completes before cancel finishes', () async {
    final cancelCompleter = Completer<void>();
    final speech = _ControllableSpeechService()
      ..cancelCompleter = cancelCompleter
      ..clearListeningWhenCancelStarts = false;
    final runtime = SpeakRuntime(
      card: _buildCard(),
      profile: _buildProfile(),
      tokenizer: _SimpleTokenizer(),
      speechService: speech,
      soundWaveService: FakeSoundWaveService(),
      cardTimer: FakeCardTimer(),
      cardDuration: const Duration(seconds: 15),
      hintText: null,
    );

    final completion = Completer<TaskCompleted>();
    final subscription = runtime.events.listen((event) {
      if (event is TaskCompleted && !completion.isCompleted) {
        completion.complete(event);
      }
    });

    await runtime.start();
    await speech.emitFinal('seven');

    final event = await completion.future.timeout(const Duration(seconds: 1));
    expect(event.outcome, TrainingOutcome.correct);
    expect(speech.cancelCallCount, 1);
    expect(speech.stopCallCount, 0);
    expect(speech.isListening, isTrue);

    cancelCompleter.complete();
    await Future<void>.delayed(Duration.zero);

    await subscription.cancel();
    await runtime.dispose();
  });

  test('accepts partial result when it completes remaining prompt', () async {
    final speech = _ControllableSpeechService();
    final runtime = SpeakRuntime(
      card: _buildCard(
        promptText: 'open door',
        acceptedAnswers: const <String>[],
      ),
      profile: _buildProfile(),
      tokenizer: _SimpleTokenizer(),
      speechService: speech,
      soundWaveService: FakeSoundWaveService(),
      cardTimer: FakeCardTimer(),
      cardDuration: const Duration(seconds: 15),
      hintText: null,
    );

    final completion = Completer<TaskCompleted>();
    final subscription = runtime.events.listen((event) {
      if (event is TaskCompleted && !completion.isCompleted) {
        completion.complete(event);
      }
    });

    await runtime.start();
    await speech.emitFinal('open');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await speech.emitPartial('door');

    final event = await completion.future.timeout(const Duration(seconds: 1));
    expect(event.outcome, TrainingOutcome.correct);

    await subscription.cancel();
    await runtime.dispose();
  });
}
