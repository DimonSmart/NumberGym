import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/runtimes/number_pronunciation_runtime.dart';
import 'package:number_gym/features/training/domain/services/speech_service.dart';
import 'package:number_gym/features/training/domain/task_runtime.dart';
import 'package:number_gym/features/training/domain/task_state.dart';
import 'package:number_gym/features/training/domain/training_outcome.dart';
import 'package:number_gym/features/training/domain/tasks/number_pronunciation_task.dart';
import 'package:number_gym/features/training/domain/tasks/time_pronunciation_task.dart';
import 'package:number_gym/features/training/domain/time_value.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'helpers/training_fakes.dart';

void main() {
  test('pause keeps remaining time and resume restarts listening', () async {
    final speech = FakeSpeechService();
    final runtime = NumberPronunciationRuntime(
      task: NumberPronunciationTask(
        id: const TrainingItemId(type: TrainingItemType.digits, number: 7),
        numberValue: 7,
        prompt: '7',
        language: LearningLanguage.english,
        answers: const <String>['seven', '7'],
      ),
      speechService: speech,
      soundWaveService: FakeSoundWaveService(),
      cardTimer: FakeCardTimer(),
      cardDuration: const Duration(seconds: 15),
      hintText: null,
      onSpeechReady: (ready, errorMessage) {},
    );

    await runtime.start();

    final startedState = runtime.state as NumberPronunciationState;
    expect(startedState.timer.isRunning, isTrue);
    expect(speech.isListening, isTrue);

    await runtime.handleAction(const PauseTaskAction());

    final pausedState = runtime.state as NumberPronunciationState;
    expect(pausedState.timer.isRunning, isFalse);
    expect(pausedState.timer.remaining, const Duration(seconds: 15));
    expect(pausedState.isListening, isFalse);
    expect(speech.isListening, isFalse);

    await runtime.handleAction(const ResumeTaskAction());

    final resumedState = runtime.state as NumberPronunciationState;
    expect(resumedState.timer.isRunning, isTrue);
    expect(speech.isListening, isTrue);

    await runtime.dispose();
  });

  test(
    'prefers stronger partial over truncated final result for time speech',
    () async {
      final speech = _ControllableSpeechService();
      final runtime = NumberPronunciationRuntime(
        task: TimePronunciationTask(
          id: const TrainingItemId(
            type: TrainingItemType.timeHalf,
            time: TimeValue(hour: 22, minute: 30),
          ),
          timeValue: const TimeValue(hour: 22, minute: 30),
          prompt: '22:30',
          language: LearningLanguage.english,
          answers: const <String>['22:30', 'half past twenty two'],
        ),
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
      await speech.emitPartial('Half past 22');
      await speech.emitFinal('22');

      final event = await completion.future.timeout(const Duration(seconds: 1));
      expect(event.outcome, TrainingOutcome.correct);
      expect(speech.listenCallCount, 1);

      await subscription.cancel();
      await runtime.dispose();
    },
  );
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
    required void Function(SpeechRecognitionError p1) onError,
    required void Function(String p1) onStatus,
    bool requestPermission = true,
  }) async {
    return const SpeechInitResult(ready: true);
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
