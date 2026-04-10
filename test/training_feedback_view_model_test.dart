import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/training_outcome.dart';
import 'package:number_gym/features/training/domain/training_state.dart';
import 'package:number_gym/features/training/ui/view_models/training_feedback_view_model.dart';

void main() {
  final theme = ThemeData();

  test('maps outcome labels without storing UI text in domain state', () {
    expect(
      TrainingFeedbackViewModel.feedbackTextFor(TrainingOutcome.correct),
      'Correct',
    );
    expect(
      TrainingFeedbackViewModel.feedbackTextFor(TrainingOutcome.wrong),
      'Wrong',
    );
    expect(
      TrainingFeedbackViewModel.feedbackTextFor(TrainingOutcome.timeout),
      'Timeout',
    );
    expect(
      TrainingFeedbackViewModel.feedbackTextFor(TrainingOutcome.skipped),
      'Skipped',
    );
  });

  test('fromFeedback preserves overlay visibility and label', () {
    final viewModel = TrainingFeedbackViewModel.fromFeedback(
      theme: theme,
      feedback: const TrainingFeedback(outcome: TrainingOutcome.correct),
    );

    expect(viewModel.text, 'Correct');
    expect(viewModel.showOverlay, isTrue);
    expect(viewModel.color, isNotNull);
  });

  test('skipped feedback does not show blocking overlay', () {
    final viewModel = TrainingFeedbackViewModel.fromFeedback(
      theme: theme,
      feedback: const TrainingFeedback(outcome: TrainingOutcome.skipped),
    );

    expect(viewModel.text, 'Skipped');
    expect(viewModel.showOverlay, isFalse);
    expect(viewModel.color, isNotNull);
  });
}
