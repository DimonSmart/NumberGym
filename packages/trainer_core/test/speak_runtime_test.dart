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
    _isListening = false;
  }

  @override
  void dispose() {
    _isListening = false;
  }

  Future<void> emitPartial(String text) async {
    _onResult?.call(
      SpeechRecognitionResult(
        <SpeechRecognitionWords>[
          SpeechRecognitionWords(
            text,
            null,
            SpeechRecognitionWords.missingConfidence,
          ),
        ],
        false,
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> emitFinal(String text) async {
    _onResult?.call(
      SpeechRecognitionResult(
        <SpeechRecognitionWords>[
          SpeechRecognitionWords(
            text,
            null,
            SpeechRecognitionWords.missingConfidence,
          ),
        ],
        true,
      ),
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
      onSpeechReady: (ready, errorMessage) {},
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

  test(
    'prefers stronger partial over truncated final result',
    () async {
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
        onSpeechReady: (ready, errorMessage) {},
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

      final event =
          await completion.future.timeout(const Duration(seconds: 1));
      expect(event.outcome, TrainingOutcome.correct);
      expect(speech.listenCallCount, 1);

      await subscription.cancel();
      await runtime.dispose();
    },
  );
}
