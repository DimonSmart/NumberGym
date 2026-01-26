import '../../domain/training_state.dart';

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
  }) {
    return TrainingStatusViewModel(
      message: _buildMessage(state),
      errorMessage: state.errorMessage,
    );
  }

  static String _buildMessage(TrainingState state) {
    final status = state.status;
    if (status == TrainerStatus.finished) {
      return 'All cards learned. Reset progress to start again.';
    }
    if (status == TrainerStatus.idle) {
      return 'Tap Start to begin training.';
    }
    return 'Get ready for the next task.';
  }
}
