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
  final String taskKey;

  bool get showFeedback => feedbackText != null;

  factory MultipleChoiceViewModel.fromState({
    required ThemeData theme,
    required MultipleChoiceState task,
    required TrainingFeedbackViewModel feedback,
  }) {
    final isTextToValue = task.kind == TrainingTaskKind.textToValue;
    final isNumericMode = isTextToValue;
    final isTimeOptions =
        isTextToValue && task.options.any((option) => option.contains(':'));
    final title =
        isTextToValue ? 'Choose the correct value' : 'Choose the correct wording';
    final promptStyle = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
      fontSize: isNumericMode ? 42 : null,
    );
    final optionStyle = isNumericMode
        ? theme.textTheme.headlineSmall
        : theme.textTheme.titleMedium;
    final optionWidth =
        isTextToValue ? (isTimeOptions ? 110.0 : 100.0) : 220.0;

    return MultipleChoiceViewModel(
      title: title,
      prompt: task.prompt,
      promptStyle: promptStyle,
      optionStyle: optionStyle,
      options: task.options,
      optionWidth: optionWidth,
      feedbackText: feedback.text,
      feedbackColor: feedback.color,
      timer: task.timer,
      isTimerActive: task.timer.isRunning,
      taskKey: task.taskId.storageKey,
    );
  }
}
