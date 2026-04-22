import 'dart:async';

import 'trainer_state.dart';

class FeedbackCoordinator {
  FeedbackCoordinator({
    required void Function() onChanged,
    Duration feedbackDuration = const Duration(milliseconds: 900),
  }) : _onChanged = onChanged,
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

    _feedback = TrainingFeedback(outcome: outcome);
    _onChanged();

    final completer = Completer<void>();
    _feedbackCompleter = completer;
    _feedbackTimer = Timer(_feedbackDuration, clear);

    final shouldHold =
        outcome == TrainingOutcome.correct ||
        outcome == TrainingOutcome.wrong ||
        outcome == TrainingOutcome.timeout;
    if (!shouldHold) {
      return Future<void>.value();
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
