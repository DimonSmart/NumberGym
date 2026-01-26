import '../../domain/training_state.dart';
import '../../domain/training_task.dart';

class TrainingStatusViewModel {
  const TrainingStatusViewModel({
    required this.message,
    required this.errorMessage,
  });

  final String message;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  factory TrainingStatusViewModel.fromState({
    required TrainingState state,
    required bool isAwaitingPronunciationReview,
  }) {
    return TrainingStatusViewModel(
      message: _buildMessage(state, isAwaitingPronunciationReview),
      errorMessage: state.errorMessage,
    );
  }

  static String _buildMessage(
    TrainingState state,
    bool isAwaitingPronunciationReview,
  ) {
    final status = state.status;
    if (isAwaitingPronunciationReview) {
      return 'Tap Next to continue.';
    }
    if (status == TrainerStatus.finished) {
      return 'All cards learned. Reset progress to start again.';
    }
    if (status == TrainerStatus.paused) {
      return 'Paused. Tap Stop to return to the start screen.';
    }
    if (status == TrainerStatus.waitingRecording) {
      return 'Waiting to record phrase. Tap Record when ready.';
    }
    if (status == TrainerStatus.idle) {
      return 'Preparing the next task...';
    }
    final taskKind = state.currentTask?.kind;
    if (taskKind == TrainingTaskKind.numberPronunciation) {
      if (!state.speechReady) {
        return 'Microphone access is required to continue.';
      }
      return 'Listening...';
    }
    if (taskKind == TrainingTaskKind.numberToWord) {
      return '';
    }
    if (taskKind == TrainingTaskKind.wordToNumber) {
      return '';
    }
    if (taskKind == TrainingTaskKind.listeningNumbers) {
      return '';
    }
    return 'Get ready for the next task.';
  }
}
