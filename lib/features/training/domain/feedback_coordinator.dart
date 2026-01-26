import 'dart:async';

import 'training_outcome.dart';
import 'training_state.dart';

class FeedbackCoordinator {
  FeedbackCoordinator({
    required void Function() onChanged,
    Duration feedbackDuration = const Duration(milliseconds: 1500),
  })  : _onChanged = onChanged,
        _feedbackDuration = feedbackDuration;

  final void Function() _onChanged;
  final Duration _feedbackDuration;

  TrainingFeedback? _feedback;
  Timer? _feedbackTimer;
  Completer<void>? _feedbackCompleter;

  TrainingFeedback? get feedback => _feedback;

  Future<void> show(TrainingOutcome outcome) {
    _feedbackTimer?.cancel();
    _feedbackCompleter?.complete();
    _feedbackCompleter = null;

    late final TrainingFeedbackType type;
    late final String text;

    switch (outcome) {
      case TrainingOutcome.success:
        type = TrainingFeedbackType.correct;
        text = 'Correct';
        break;
      case TrainingOutcome.fail:
        type = TrainingFeedbackType.wrong;
        text = 'Wrong';
        break;
      case TrainingOutcome.timeout:
        type = TrainingFeedbackType.timeout;
        text = 'Timeout';
        break;
      case TrainingOutcome.ignore:
        type = TrainingFeedbackType.skipped;
        text = 'Skipped';
        break;
    }

    _feedback = TrainingFeedback(type: type, text: text);
    _onChanged();

    final completer = Completer<void>();
    _feedbackCompleter = completer;
    _feedbackTimer = Timer(_feedbackDuration, clear);

    final shouldHold = type == TrainingFeedbackType.correct ||
        type == TrainingFeedbackType.wrong ||
        type == TrainingFeedbackType.timeout;
    if (!shouldHold) {
      return Future.value();
    }
    return completer.future;
  }

  void clear() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _feedback = null;
    _onChanged();
    _feedbackCompleter?.complete();
    _feedbackCompleter = null;
  }

  void dispose() {
    clear();
  }
}
