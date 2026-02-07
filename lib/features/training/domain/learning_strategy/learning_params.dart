class LearningParams {
  static const double maxReviewIntervalDays = 7.0;
  static const int minSpacedSuccessClustersToLearn = 3;

  final int activeLimit;
  final double clusterSuccessAccuracy;
  final int clusterMaxGapMinutes;
  final int maxStoredClusters;
  final int minDaysBetweenCountedSuccesses;
  final int minSpacedSuccessClusters;
  final double learnedIntervalDays;
  final double easeUpOnSuccess;
  final double easeDownOnFail;
  final double failIntervalFactor;
  final double minIntervalDays;
  final double maxIntervalDays;
  final double easeMin;
  final double easeMax;
  final double initialEase;
  final double initialIntervalDays;

  const LearningParams({
    required this.activeLimit,
    required this.clusterSuccessAccuracy,
    required this.clusterMaxGapMinutes,
    required this.maxStoredClusters,
    required this.minDaysBetweenCountedSuccesses,
    required this.minSpacedSuccessClusters,
    required this.learnedIntervalDays,
    required this.easeUpOnSuccess,
    required this.easeDownOnFail,
    required this.failIntervalFactor,
    required this.minIntervalDays,
    required this.maxIntervalDays,
    required this.easeMin,
    required this.easeMax,
    required this.initialEase,
    required this.initialIntervalDays,
  }) : assert(activeLimit > 0),
       assert(clusterSuccessAccuracy >= 0 && clusterSuccessAccuracy <= 1),
       assert(clusterMaxGapMinutes >= 0),
       assert(maxStoredClusters > 0),
       assert(minDaysBetweenCountedSuccesses >= 0),
       assert(minSpacedSuccessClusters >= 0),
       assert(learnedIntervalDays >= 0),
       assert(minIntervalDays > 0),
       assert(maxIntervalDays >= minIntervalDays),
       assert(easeMin > 0),
       assert(easeMax >= easeMin),
       assert(initialEase > 0),
       assert(initialIntervalDays > 0);

  factory LearningParams.defaults() {
    return const LearningParams(
      activeLimit: 20,
      clusterSuccessAccuracy: 0.8,
      clusterMaxGapMinutes: 30,
      maxStoredClusters: 10,
      minDaysBetweenCountedSuccesses: 1,
      minSpacedSuccessClusters: minSpacedSuccessClustersToLearn,
      learnedIntervalDays: maxReviewIntervalDays,
      easeUpOnSuccess: 0.04,
      easeDownOnFail: 0.1,
      failIntervalFactor: 0.6,
      minIntervalDays: 1,
      maxIntervalDays: maxReviewIntervalDays,
      easeMin: 1.2,
      easeMax: 1.8,
      initialEase: 1.3,
      initialIntervalDays: 1.0,
    );
  }

  double clampEase(double value) {
    return value.clamp(easeMin, easeMax).toDouble();
  }

  double clampInterval(double value) {
    return value.clamp(minIntervalDays, maxIntervalDays).toDouble();
  }
}
