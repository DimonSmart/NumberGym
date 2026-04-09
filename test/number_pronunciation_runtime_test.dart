import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/runtimes/number_pronunciation_runtime.dart';
import 'package:number_gym/features/training/domain/task_runtime.dart';
import 'package:number_gym/features/training/domain/task_state.dart';
import 'package:number_gym/features/training/domain/tasks/number_pronunciation_task.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';

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
}
