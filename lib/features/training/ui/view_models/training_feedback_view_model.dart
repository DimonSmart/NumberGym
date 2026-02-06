import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/training_outcome.dart';
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
        : _resolveFeedbackColor(theme, feedback.outcome);
    final showOverlay = feedback != null &&
        (feedback.outcome == TrainingOutcome.correct ||
            feedback.outcome == TrainingOutcome.wrong ||
            feedback.outcome == TrainingOutcome.timeout);

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
    TrainingOutcome outcome,
  ) {
    switch (outcome) {
      case TrainingOutcome.correct:
        return AppPalette.deepBlue;
      case TrainingOutcome.wrong:
      case TrainingOutcome.timeout:
        return Colors.red.shade700;
      case TrainingOutcome.skipped:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
