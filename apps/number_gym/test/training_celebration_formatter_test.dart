import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/task_state.dart';
import 'package:number_gym/features/training/domain/time_value.dart';
import 'package:number_gym/features/training/domain/training_celebration_formatter.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';

void main() {
  test('masteredText prioritizes numeric and time-based values', () {
    const formatter = TrainingCelebrationFormatter();

    final numberState = MultipleChoiceState(
      kind: LearningMethod.valueToText,
      taskId: const TrainingItemId(type: TrainingItemType.digits, number: 7),
      numberValue: 7,
      displayText: 'seven',
      timer: TimerState.zero,
      prompt: '7',
      options: const <String>['seven'],
    );
    expect(formatter.masteredText(numberState), '7');

    final listeningState = ListeningState(
      taskId: const TrainingItemId(type: TrainingItemType.timeRandom),
      timeValue: const TimeValue(hour: 9, minute: 30),
      displayText: 'ignored',
      timer: TimerState.zero,
      options: const <String>['09:30'],
      isAnswerRevealed: false,
      isPromptPlaying: false,
    );
    expect(formatter.masteredText(listeningState), '09:30');
  });

  test('masteredText supports clock string fallback and category labels', () {
    const formatter = TrainingCelebrationFormatter();

    final state = MultipleChoiceState(
      kind: LearningMethod.valueToText,
      taskId: const TrainingItemId(type: TrainingItemType.timeRandom),
      numberValue: null,
      displayText: '12:34',
      timer: TimerState.zero,
      prompt: 'ignored',
      options: const <String>[],
    );

    expect(formatter.masteredText(state), '12:34');
    expect(
      formatter.categoryLabel(TrainingItemType.phone3222),
      'Phone numbers (3-2-2-2)',
    );
  });
}
