import '../training_item.dart';

class LearningParams {
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
  }) : assert(dailyAttemptLimit > 0),
       assert(dailyNewCardsLimit >= 0),
       assert(clusterMaxGapMinutes >= 0),
       assert(maxStoredClusters > 0),
       assert(recentAttemptsWindow > 0),
       assert(minAttemptsToLearn > 0),
       assert(repeatCooldownCards >= 0),
       assert(easyMasteryAccuracy >= 0 && easyMasteryAccuracy <= 1),
       assert(mediumMasteryAccuracy >= 0 && mediumMasteryAccuracy <= 1),
       assert(hardMasteryAccuracy >= 0 && hardMasteryAccuracy <= 1),
       assert(easyTypeWeight > 0),
       assert(mediumTypeWeight > 0),
       assert(hardTypeWeight > 0),
       assert(weaknessBoost >= 0),
       assert(newCardBoost > 0),
       assert(recentMistakeBoost > 0),
       assert(cooldownPenalty > 0);

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

  double targetAccuracy(TrainingItemType type) {
    switch (type) {
      case TrainingItemType.phone33x3:
      case TrainingItemType.phone3222:
      case TrainingItemType.phone2322:
        return 0.8;
      default:
        break;
    }
    switch (_difficultyFor(type)) {
      case _ItemDifficulty.easy:
        return easyMasteryAccuracy;
      case _ItemDifficulty.medium:
        return mediumMasteryAccuracy;
      case _ItemDifficulty.hard:
        return hardMasteryAccuracy;
    }
  }

  int requiredCorrectAttemptsToLearn(TrainingItemType type) {
    final required = (minAttemptsToLearn * targetAccuracy(type)).ceil();
    return required < 1 ? 1 : required;
  }

  int hintVisibleUntilCorrectStreak(TrainingItemType type) {
    return requiredCorrectAttemptsToLearn(type) ~/ 2;
  }

  double baseTypeWeight(TrainingItemType type) {
    switch (_difficultyFor(type)) {
      case _ItemDifficulty.easy:
        return easyTypeWeight;
      case _ItemDifficulty.medium:
        return mediumTypeWeight;
      case _ItemDifficulty.hard:
        return hardTypeWeight;
    }
  }

  _ItemDifficulty _difficultyFor(TrainingItemType type) {
    switch (type) {
      case TrainingItemType.digits:
      case TrainingItemType.base:
        return _ItemDifficulty.easy;
      case TrainingItemType.hundreds:
      case TrainingItemType.thousands:
      case TrainingItemType.timeExact:
      case TrainingItemType.timeHalf:
        return _ItemDifficulty.medium;
      case TrainingItemType.timeQuarter:
      case TrainingItemType.timeRandom:
      case TrainingItemType.phone33x3:
      case TrainingItemType.phone3222:
      case TrainingItemType.phone2322:
        return _ItemDifficulty.hard;
    }
  }
}

enum _ItemDifficulty { easy, medium, hard }
