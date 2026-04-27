import 'dart:math' as math;

import 'exercise_models.dart';
import 'learning_params.dart';
import 'training/data/card_progress.dart';

class CardLearningProgress {
  const CardLearningProgress({
    required this.creditedCorrectAttempts,
    required this.requiredCorrectAttempts,
  });

  factory CardLearningProgress.forCard({
    required ExerciseFamily family,
    required CardProgress progress,
    required LearningParams learningParams,
  }) {
    final requiredCorrectAttempts = learningParams
        .requiredCorrectAttemptsToLearnForFamily(family);
    final creditedCorrectAttempts = progress.learned
        ? requiredCorrectAttempts
        : math.min(progress.totalCorrect, requiredCorrectAttempts);
    return CardLearningProgress(
      creditedCorrectAttempts: creditedCorrectAttempts,
      requiredCorrectAttempts: requiredCorrectAttempts,
    );
  }

  final int creditedCorrectAttempts;
  final int requiredCorrectAttempts;

  double get progressValue {
    if (requiredCorrectAttempts <= 0) {
      return 0;
    }
    return creditedCorrectAttempts / requiredCorrectAttempts;
  }
}
