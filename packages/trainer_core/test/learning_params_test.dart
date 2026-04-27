import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  test('family mastery override adjusts target accuracy and hint window', () {
    final family = ExerciseFamily(
      moduleId: 'number_gym',
      id: 'phone33x3',
      label: 'Phone numbers (3-3-3)',
      shortLabel: 'Phone 3-3-3',
      difficultyTier: ExerciseDifficultyTier.hard,
      defaultDuration: const Duration(seconds: 30),
      supportedModes: const <ExerciseMode>[ExerciseMode.speak],
      masteryAccuracy: 0.8,
    );

    final params = LearningParams.defaults();

    expect(params.targetAccuracyForFamily(family), 0.8);
    expect(params.requiredCorrectAttemptsToLearnForFamily(family), 16);
    expect(params.hintVisibleUntilCorrectStreakForFamily(family), 8);
  });

  test('card learning progress uses shared mastery thresholds', () {
    final family = ExerciseFamily(
      moduleId: 'number_gym',
      id: 'phone33x3',
      label: 'Phone numbers (3-3-3)',
      shortLabel: 'Phone 3-3-3',
      difficultyTier: ExerciseDifficultyTier.hard,
      defaultDuration: const Duration(seconds: 30),
      supportedModes: const <ExerciseMode>[ExerciseMode.speak],
      masteryAccuracy: 0.8,
    );
    final params = LearningParams.defaults();

    final activeProgress = CardLearningProgress.forCard(
      family: family,
      progress: const CardProgress(
        learned: false,
        clusters: <CardCluster>[
          CardCluster(
            lastAnswerAt: 1,
            correctCount: 19,
            wrongCount: 3,
            skippedCount: 0,
          ),
        ],
        learnedAt: 0,
        firstAttemptAt: 1,
      ),
      learningParams: params,
    );

    expect(activeProgress.creditedCorrectAttempts, 16);
    expect(activeProgress.requiredCorrectAttempts, 16);
    expect(activeProgress.progressValue, 1);

    final learnedProgress = CardLearningProgress.forCard(
      family: family,
      progress: const CardProgress(
        learned: true,
        clusters: <CardCluster>[],
        learnedAt: 1,
        firstAttemptAt: 1,
      ),
      learningParams: params,
    );

    expect(learnedProgress.creditedCorrectAttempts, 16);
    expect(learnedProgress.requiredCorrectAttempts, 16);
    expect(learnedProgress.progressValue, 1);
  });
}
