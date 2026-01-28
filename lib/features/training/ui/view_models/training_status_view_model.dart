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
      message: '',
      errorMessage: state.errorMessage,
    );
  }
}
