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
}
