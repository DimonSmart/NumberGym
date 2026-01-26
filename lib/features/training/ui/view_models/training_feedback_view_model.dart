import 'package:flutter/material.dart';

import '../../domain/training_state.dart';

class TrainingFeedbackViewModel {
  const TrainingFeedbackViewModel({
    required this.feedback,
    required this.text,
    required this.color,
    required this.overlayColor,
    required this.showOverlay,
  });

  final TrainingFeedback? feedback;
  final String? text;
  final Color? color;
  final Color overlayColor;
  final bool showOverlay;

  bool get hasText => text != null && text!.isNotEmpty;

  factory TrainingFeedbackViewModel.fromFeedback({
    required ThemeData theme,
    required TrainingFeedback? feedback,
  }) {
    final color = feedback == null
        ? null
        : _resolveFeedbackColor(theme, feedback.type);
    final showOverlay = feedback != null &&
        (feedback.type == TrainingFeedbackType.correct ||
            feedback.type == TrainingFeedbackType.wrong ||
            feedback.type == TrainingFeedbackType.timeout);

    return TrainingFeedbackViewModel(
      feedback: feedback,
      text: feedback?.text,
      color: color,
      overlayColor: color ?? theme.colorScheme.primary,
      showOverlay: showOverlay,
    );
  }

  static Color _resolveFeedbackColor(
    ThemeData theme,
    TrainingFeedbackType type,
  ) {
    switch (type) {
      case TrainingFeedbackType.correct:
        return Colors.green.shade700;
      case TrainingFeedbackType.wrong:
      case TrainingFeedbackType.timeout:
        return Colors.red.shade700;
      case TrainingFeedbackType.skipped:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
