import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/ui/view_models/multiple_choice_view_model.dart';
import 'package:number_gym/features/training/ui/view_models/training_feedback_view_model.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  final theme = ThemeData();
  final feedback = TrainingFeedbackViewModel.fromFeedback(
    theme: theme,
    feedback: null,
  );

  test('chooseFromAnswer shows wording prompt with value options', () {
    final state = _choiceState(
      mode: ExerciseMode.chooseFromAnswer,
      displayText: 'twenty one',
      promptText: '21',
      options: const <String>['21', '22', '23', '24'],
    );

    final viewModel = MultipleChoiceViewModel.fromState(
      theme: theme,
      task: state,
      feedback: feedback,
    );

    expect(viewModel.title, 'Choose the correct value');
    expect(viewModel.prompt, 'twenty one');
    expect(viewModel.optionWidth, 100);
  });

  test('chooseFromPrompt shows value prompt with wording options', () {
    final state = _choiceState(
      mode: ExerciseMode.chooseFromPrompt,
      displayText: '21',
      promptText: '21',
      options: const <String>['twenty one', 'twenty two', 'twenty three'],
    );

    final viewModel = MultipleChoiceViewModel.fromState(
      theme: theme,
      task: state,
      feedback: feedback,
    );

    expect(viewModel.title, 'Choose the correct wording');
    expect(viewModel.prompt, '21');
    expect(viewModel.optionWidth, 220);
  });
}

ChoiceState _choiceState({
  required ExerciseMode mode,
  required String displayText,
  required String promptText,
  required List<String> options,
}) {
  return ChoiceState(
    mode: mode,
    exerciseId: const ExerciseId(
      moduleId: 'number_gym',
      familyId: 'base',
      variantId: '21',
    ),
    family: _family,
    displayText: displayText,
    promptText: promptText,
    acceptedAnswers: const <String>['21', 'twenty one'],
    celebrationText: '21 -> twenty one',
    timer: TimerState.zero,
    options: options,
  );
}

final _family = ExerciseFamily(
  moduleId: 'number_gym',
  id: 'base',
  label: 'Base',
  shortLabel: 'Base',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: const Duration(seconds: 15),
  supportedModes: const <ExerciseMode>[
    ExerciseMode.chooseFromPrompt,
    ExerciseMode.chooseFromAnswer,
  ],
);
