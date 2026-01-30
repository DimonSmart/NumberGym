import 'package:flutter/material.dart';

import '../../domain/task_state.dart';
import 'training_feedback_view_model.dart';

class ListeningNumbersViewModel {
  const ListeningNumbersViewModel({
    required this.title,
    required this.displayText,
    required this.showReplayHint,
    required this.replayHintText,
    required this.promptStyle,
    required this.options,
    required this.optionWidth,
    required this.feedbackText,
    required this.feedbackColor,
    required this.timer,
    required this.isTimerActive,
    required this.taskKey,
  });

  final String title;
  final String displayText;
  final bool showReplayHint;
  final String replayHintText;
  final TextStyle? promptStyle;
  final List<String> options;
  final double optionWidth;
  final String? feedbackText;
  final Color? feedbackColor;
  final TimerState timer;
  final bool isTimerActive;
  final String taskKey;

  bool get showFeedback => feedbackText != null;

  factory ListeningNumbersViewModel.fromState({
    required ThemeData theme,
    required ListeningNumbersState task,
    required TrainingFeedbackViewModel feedback,
  }) {
    final displayText = task.displayText.isEmpty ? '?' : task.displayText;
    return ListeningNumbersViewModel(
      title: 'Listen and choose the number',
      displayText: displayText,
      showReplayHint: !task.isAnswerRevealed,
      replayHintText: 'Tap ? to listen again',
      promptStyle: theme.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
        fontSize: 56,
      ),
      options: task.options,
      optionWidth: 100,
      feedbackText: feedback.text,
      feedbackColor: feedback.color,
      timer: task.timer,
      isTimerActive: task.timer.isRunning,
      taskKey: task.taskId.storageKey,
    );
  }
}
