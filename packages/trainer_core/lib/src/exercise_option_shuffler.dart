import 'dart:math';

import 'exercise_models.dart';

class ExerciseOptionShuffler {
  ExerciseOptionShuffler(Random random) : _random = random;

  final Random _random;

  ChoiceExerciseSpec shuffleChoice(ChoiceExerciseSpec spec) {
    return ChoiceExerciseSpec(
      prompt: spec.prompt,
      correctOption: spec.correctOption,
      options: _shuffledOptions(spec.options),
    );
  }

  ListeningExerciseSpec shuffleListening(ListeningExerciseSpec spec) {
    return ListeningExerciseSpec(
      speechText: spec.speechText,
      correctOption: spec.correctOption,
      options: _shuffledOptions(spec.options),
    );
  }

  List<String> _shuffledOptions(List<String> options) {
    final shuffled = List<String>.from(options);
    for (var index = shuffled.length - 1; index > 0; index -= 1) {
      final swapIndex = _random.nextInt(index + 1);
      final current = shuffled[index];
      shuffled[index] = shuffled[swapIndex];
      shuffled[swapIndex] = current;
    }
    return shuffled;
  }
}
