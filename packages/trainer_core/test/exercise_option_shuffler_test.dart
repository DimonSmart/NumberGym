import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/src/exercise_option_shuffler.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  test('choice options are shuffled without changing the correct answer', () {
    final shuffler = ExerciseOptionShuffler(_ZeroRandom());
    final spec = ChoiceExerciseSpec(
      prompt: 'prompt',
      correctOption: 'correct',
      options: const <String>['correct', 'a', 'b', 'c'],
    );

    final shuffled = shuffler.shuffleChoice(spec);

    expect(shuffled.correctOption, 'correct');
    expect(shuffled.options, const <String>['a', 'b', 'c', 'correct']);
  });

  test('listening options are shuffled without changing speech text', () {
    final shuffler = ExerciseOptionShuffler(_ZeroRandom());
    final spec = ListeningExerciseSpec(
      speechText: 'listen',
      correctOption: 'correct',
      options: const <String>['correct', 'a', 'b', 'c'],
    );

    final shuffled = shuffler.shuffleListening(spec);

    expect(shuffled.speechText, 'listen');
    expect(shuffled.correctOption, 'correct');
    expect(shuffled.options, const <String>['a', 'b', 'c', 'correct']);
  });
}

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
