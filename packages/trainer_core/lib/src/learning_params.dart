import 'exercise_models.dart';

class LearningParams {
  const LearningParams({
    required this.dailyAttemptLimit,
    required this.dailyNewCardsLimit,
    required this.clusterMaxGapMinutes,
    required this.maxStoredClusters,
    required this.recentAttemptsWindow,
    required this.minAttemptsToLearn,
    required this.repeatCooldownCards,
    required this.easyMasteryAccuracy,
    required this.mediumMasteryAccuracy,
    required this.hardMasteryAccuracy,
    required this.easyTypeWeight,
    required this.mediumTypeWeight,
    required this.hardTypeWeight,
    required this.weaknessBoost,
    required this.newCardBoost,
    required this.recentMistakeBoost,
    required this.cooldownPenalty,
  });

  factory LearningParams.defaults() {
    return const LearningParams(
      dailyAttemptLimit: 50,
      dailyNewCardsLimit: 15,
      clusterMaxGapMinutes: 30,
      maxStoredClusters: 32,
      recentAttemptsWindow: 10,
      minAttemptsToLearn: 20,
      repeatCooldownCards: 2,
      easyMasteryAccuracy: 1.0,
      mediumMasteryAccuracy: 0.85,
      hardMasteryAccuracy: 0.75,
      easyTypeWeight: 1.8,
      mediumTypeWeight: 1.1,
      hardTypeWeight: 0.7,
      weaknessBoost: 2.0,
      newCardBoost: 1.4,
      recentMistakeBoost: 1.3,
      cooldownPenalty: 0.2,
    );
  }

  final int dailyAttemptLimit;
  final int dailyNewCardsLimit;
  final int clusterMaxGapMinutes;
  final int maxStoredClusters;
  final int recentAttemptsWindow;
  final int minAttemptsToLearn;
  final int repeatCooldownCards;
  final double easyMasteryAccuracy;
  final double mediumMasteryAccuracy;
  final double hardMasteryAccuracy;
  final double easyTypeWeight;
  final double mediumTypeWeight;
  final double hardTypeWeight;
  final double weaknessBoost;
  final double newCardBoost;
  final double recentMistakeBoost;
  final double cooldownPenalty;

  double targetAccuracy(ExerciseDifficultyTier tier) {
    switch (tier) {
      case ExerciseDifficultyTier.easy:
        return easyMasteryAccuracy;
      case ExerciseDifficultyTier.medium:
        return mediumMasteryAccuracy;
      case ExerciseDifficultyTier.hard:
        return hardMasteryAccuracy;
    }
  }

  double targetAccuracyForFamily(ExerciseFamily family) {
    final override = family.masteryAccuracy;
    if (override != null) {
      return override;
    }
    return targetAccuracy(family.difficultyTier);
  }

  int requiredCorrectAttemptsToLearn(ExerciseDifficultyTier tier) {
    final required = (minAttemptsToLearn * targetAccuracy(tier)).ceil();
    return required < 1 ? 1 : required;
  }

  int requiredCorrectAttemptsToLearnForFamily(ExerciseFamily family) {
    final required = (minAttemptsToLearn * targetAccuracyForFamily(family))
        .ceil();
    return required < 1 ? 1 : required;
  }

  int hintVisibleUntilCorrectStreak(ExerciseDifficultyTier tier) {
    return requiredCorrectAttemptsToLearn(tier) ~/ 2;
  }

  int hintVisibleUntilCorrectStreakForFamily(ExerciseFamily family) {
    return requiredCorrectAttemptsToLearnForFamily(family) ~/ 2;
  }

  double baseTypeWeight(ExerciseDifficultyTier tier) {
    switch (tier) {
      case ExerciseDifficultyTier.easy:
        return easyTypeWeight;
      case ExerciseDifficultyTier.medium:
        return mediumTypeWeight;
      case ExerciseDifficultyTier.hard:
        return hardTypeWeight;
    }
  }
}
