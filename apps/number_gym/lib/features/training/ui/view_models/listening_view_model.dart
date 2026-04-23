import 'package:flutter/material.dart';
import 'package:trainer_core/trainer_core.dart' show ListenAndChooseState, TimerState;

import 'training_feedback_view_model.dart';

class ListeningViewModel {
  const ListeningViewModel({
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

  factory ListeningViewModel.fromState({
    required ThemeData theme,
    required ListenAndChooseState task,
    required TrainingFeedbackViewModel feedback,
  }) {
    final displayText = task.displayText.isEmpty ? '?' : task.displayText;
    final title = task.exerciseId.familyId.contains('time')
        ? 'Listen and choose the time'
        : 'Listen and choose the number';

    return ListeningViewModel(
      title: title,
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
      taskKey: task.exerciseId.storageKey,
    );
  }
}
