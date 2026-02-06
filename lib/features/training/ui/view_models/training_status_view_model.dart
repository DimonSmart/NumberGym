import '../../domain/training_state.dart';

class TrainingStatusViewModel {
  const TrainingStatusViewModel({
    required this.message,
    required this.errorMessage,
    this.sessionStats,
  });

  final String message;
  final String? errorMessage;
  final SessionStats? sessionStats;

  bool get hasError => errorMessage != null;
  bool get sessionFinished => sessionStats != null;

  factory TrainingStatusViewModel.fromState({
    required TrainingState state,
  }) {
    return TrainingStatusViewModel(
      message: '',
      errorMessage: state.errorMessage,
      sessionStats: state.sessionStats,
    );
  }
}
