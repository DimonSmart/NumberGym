import 'package:flutter/material.dart';

import '../../domain/task_state.dart';
import '../../domain/training_task.dart';
import 'training_feedback_view_model.dart';

class MultipleChoiceViewModel {
  const MultipleChoiceViewModel({
    required this.title,
    required this.prompt,
    required this.promptStyle,
    required this.optionStyle,
    required this.options,
    required this.optionWidth,
    required this.feedbackText,
    required this.feedbackColor,
    required this.timer,
    required this.isTimerActive,
    required this.taskKey,
  });

  final String title;
  final String prompt;
  final TextStyle? promptStyle;
  final TextStyle? optionStyle;
  final List<String> options;
  final double optionWidth;
  final String? feedbackText;
  final Color? feedbackColor;
  final TimerState timer;
  final bool isTimerActive;
  final int taskKey;

  bool get showFeedback => feedbackText != null;

  factory MultipleChoiceViewModel.fromState({
    required ThemeData theme,
    required MultipleChoiceState task,
    required TrainingFeedbackViewModel feedback,
  }) {
    final isWordToNumber = task.kind == TrainingTaskKind.wordToNumber;
    final title =
        isWordToNumber ? 'Choose the correct number' : 'Choose the correct spelling';
    final promptStyle = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
      fontSize: isWordToNumber ? 42 : null,
    );
    final optionStyle =
        isWordToNumber ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium;

    return MultipleChoiceViewModel(
      title: title,
      prompt: task.prompt,
      promptStyle: promptStyle,
      optionStyle: optionStyle,
      options: task.options,
      optionWidth: isWordToNumber ? 100 : 220,
      feedbackText: feedback.text,
      feedbackColor: feedback.color,
      timer: task.timer,
      isTimerActive: task.timer.isRunning,
      taskKey: task.numberValue,
    );
  }
}
