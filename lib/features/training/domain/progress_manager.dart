import 'dart:math';

import '../data/card_progress.dart';
import 'daily_study_summary.dart';
import 'learning_language.dart';
import 'learning_strategy/learning_params.dart';
import 'language_router.dart';
import 'repositories.dart';
import 'training_catalog.dart';
import 'training_item.dart';
import 'training_task.dart';

class PickedCard {
  const PickedCard({required this.card});

  final PronunciationTaskData card;
}

class ProgressAttemptResult {
  const ProgressAttemptResult({
    required this.learned,
    required this.newCluster,
  });

  final bool learned;
  final bool newCluster;
}

class ProgressManager {
  ProgressManager({
    required ProgressRepositoryBase progressRepository,
    required LanguageRouter languageRouter,
    TrainingCatalog? catalog,
    LearningParams? learningParams,
    Random? random,
  }) : _progressRepository = progressRepository,
       _languageRouter = languageRouter,
       _catalog = catalog ?? TrainingCatalog.defaults(),
       _random = random ?? Random(),
       _learningParams = learningParams ?? LearningParams.defaults();

  final ProgressRepositoryBase _progressRepository;
  final LanguageRouter _languageRouter;
  final TrainingCatalog _catalog;
  final Random _random;
  final LearningParams _learningParams;

  Map<TrainingItemId, PronunciationTaskData> _cardsById = {};
  List<TrainingItemId> _cardIds = [];
  LearningLanguage? _cardsLanguage;

  Map<TrainingItemId, CardProgress> _progressById = {};
  final List<TrainingItemId> _recentPickHistory = <TrainingItemId>[];

  LearningLanguage? get cardsLanguage => _cardsLanguage;
  List<TrainingItemId> get cardIds => _cardIds;
  LearningParams get learningParams => _learningParams;

  int get totalCards => _cardsById.length;
  int get learnedCount =>
      _progressById.values.where((progress) => progress.learned).length;
  int get remainingCount => totalCards - learnedCount;
  bool get hasRemainingCards => _cardsById.isNotEmpty;

  LearningQueueDebugSnapshot debugQueueSnapshot({DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final newCardsLimitReached = _isDailyNewLimitReached(resolvedNow);

    final weightById = <TrainingItemId, double>{};
    for (final id in _cardIds) {
      final progress = _progressById[id] ?? CardProgress.empty;
      weightById[id] = _cardWeight(
        id,
        progress,
        now: resolvedNow,
        newCardsLimitReached: newCardsLimitReached,
        applyCooldown: false,
      );
    }

    final prioritized = _cardIds.toList()
      ..sort((a, b) {
        final aWeight = weightById[a] ?? 0;
        final bWeight = weightById[b] ?? 0;
        final diff = bWeight.compareTo(aWeight);
        if (diff != 0) return diff;
        return a.compareTo(b);
      });

    return LearningQueueDebugSnapshot(
      language: _cardsLanguage,
      prioritized: prioritized.take(60).toList(),
      all: _cardIds,
      weightById: weightById,
      progressById: Map<TrainingItemId, CardProgress>.unmodifiable(
        _progressById,
      ),
      dailyAttemptLimit: _learningParams.dailyAttemptLimit,
      dailyAttemptsToday: _countAttemptsToday(resolvedNow),
      dailyNewCardsLimit: _learningParams.dailyNewCardsLimit,
      dailyNewCardsToday: _countNewCardsStartedToday(resolvedNow),
    );
  }

  DailyStudySummary dailySummary({DateTime? now}) {
    return DailyStudySummary.fromProgress(
      _progressById.values,
      now: now,
      dailyAttemptLimit: _learningParams.dailyAttemptLimit,
      dailyNewCardsLimit: _learningParams.dailyNewCardsLimit,
    );
  }

  PronunciationTaskData? cardById(TrainingItemId id) => _cardsById[id];

  void refreshCardsIfNeeded(LearningLanguage language) {
    if (_cardsLanguage == language && _cardsById.isNotEmpty) return;
    _cardsLanguage = language;
    final cards = _catalog.buildCards(
      language: language,
      toWords: _languageRouter.numberWordsConverter(language),
    );
    _cardsById = {for (final card in cards) card.progressId: card};
    _cardIds = _cardsById.keys.toList()..sort();
  }

  Future<void> loadProgress(LearningLanguage language) async {
    refreshCardsIfNeeded(language);
    if (_cardIds.isEmpty) {
      _progressById = {};
      _recentPickHistory.clear();
      return;
    }
    final progress = await _progressRepository.loadAll(
      _cardIds,
      language: language,
    );
    _progressById = {
      for (final id in _cardIds) id: progress[id] ?? CardProgress.empty,
    };
    _recentPickHistory.clear();
  }

  PickedCard? pickNextCard({
    required bool Function(PronunciationTaskData card) isEligible,
    DateTime? now,
  }) {
    if (_cardIds.isEmpty) return null;

    final resolvedNow = now ?? DateTime.now();
    final eligibleIds = <TrainingItemId>[];
    for (final id in _cardIds) {
      final card = _cardsById[id];
      if (card == null) continue;
      if (isEligible(card)) {
        eligibleIds.add(id);
      }
    }

    if (eligibleIds.isEmpty) return null;

    final learnedIds = <TrainingItemId>[];
    var unlearnedIds = <TrainingItemId>[];
    for (final id in eligibleIds) {
      final progress = _progressById[id] ?? CardProgress.empty;
      if (progress.learned) {
        learnedIds.add(id);
      } else {
        unlearnedIds.add(id);
      }
    }

    final newCardsLimitReached = _isDailyNewLimitReached(resolvedNow);
    if (newCardsLimitReached && unlearnedIds.isNotEmpty) {
      final practiced = unlearnedIds
          .where(
            (id) => (_progressById[id] ?? CardProgress.empty).totalAttempts > 0,
          )
          .toList();
      if (practiced.isNotEmpty) {
        unlearnedIds = practiced;
      }
    }

    final source = _resolveSourceBucket(
      learnedIds: learnedIds,
      unlearnedIds: unlearnedIds,
    );
    if (source.isEmpty) return null;

    final weightById = <TrainingItemId, double>{};
    for (final id in source) {
      final progress = _progressById[id] ?? CardProgress.empty;
      weightById[id] = _cardWeight(
        id,
        progress,
        now: resolvedNow,
        newCardsLimitReached: newCardsLimitReached,
      );
    }

    final pickedId = _pickWeightedId(source, weightById);
    if (pickedId == null) return null;

    final pickedCard = _cardsById[pickedId];
    if (pickedCard == null) return null;

    _rememberPicked(pickedId);
    return PickedCard(card: pickedCard);
  }

  Future<ProgressAttemptResult> recordAttempt({
    required TrainingItemId progressKey,
    required bool isCorrect,
    required bool isSkipped,
    required LearningLanguage language,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final progress = _progressById[progressKey] ?? CardProgress.empty;

    final clusters = List<CardCluster>.from(progress.clusters);
    final updatedLastAnswerAt = timestamp.millisecondsSinceEpoch;
    final lastCluster = clusters.isEmpty ? null : clusters.last;

    final gapMinutes = _learningParams.clusterMaxGapMinutes;
    final withinGap =
        lastCluster != null &&
        lastCluster.lastAnswerAt > 0 &&
        timestamp.difference(
              DateTime.fromMillisecondsSinceEpoch(lastCluster.lastAnswerAt),
            ) <=
            Duration(minutes: gapMinutes);

    final createdNewCluster = !withinGap;
    if (withinGap) {
      clusters[clusters.length - 1] = _updateCluster(
        lastCluster,
        isCorrect: isCorrect,
        isSkipped: isSkipped,
        lastAnswerAt: updatedLastAnswerAt,
      );
    } else {
      clusters.add(
        CardCluster(
          lastAnswerAt: updatedLastAnswerAt,
          correctCount: isCorrect ? 1 : 0,
          wrongCount: (!isCorrect && !isSkipped) ? 1 : 0,
          skippedCount: isSkipped ? 1 : 0,
        ),
      );
    }

    final maxClusters = _learningParams.maxStoredClusters;
    if (clusters.length > maxClusters) {
      final overflow = clusters.length - maxClusters;
      clusters.removeRange(0, overflow);
    }

    var updated = progress.copyWith(clusters: clusters);
    if (updated.firstAttemptAt == 0) {
      updated = updated.copyWith(firstAttemptAt: updatedLastAnswerAt);
    }

    final wasLearned = progress.learned;
    final isLearnedNow = _meetsMastery(progressKey.type, updated);
    updated = updated.copyWith(
      learned: isLearnedNow,
      learnedAt: isLearnedNow
          ? (updated.learnedAt > 0 ? updated.learnedAt : updatedLastAnswerAt)
          : 0,
    );

    _progressById[progressKey] = updated;
    await _progressRepository.save(progressKey, updated, language: language);

    return ProgressAttemptResult(
      learned: !wasLearned && isLearnedNow,
      newCluster: createdNewCluster,
    );
  }

  CardCluster _updateCluster(
    CardCluster cluster, {
    required bool isCorrect,
    required bool isSkipped,
    required int lastAnswerAt,
  }) {
    return cluster.copyWith(
      lastAnswerAt: lastAnswerAt,
      correctCount: cluster.correctCount + (isCorrect ? 1 : 0),
      wrongCount: cluster.wrongCount + (!isCorrect && !isSkipped ? 1 : 0),
      skippedCount: cluster.skippedCount + (isSkipped ? 1 : 0),
    );
  }

  void resetSelection() {
    _recentPickHistory.clear();
  }

  DateTime? getEarliestNextDue() {
    return dailySummary().nextDue;
  }

  bool _meetsMastery(TrainingItemType type, CardProgress progress) {
    if (progress.totalAttempts < _learningParams.minAttemptsToLearn) {
      return false;
    }
    final accuracy = progress.recentAccuracy(
      windowAttempts: _learningParams.recentAttemptsWindow,
    );
    final target = _learningParams.targetAccuracy(type);
    return accuracy >= target;
  }

  List<TrainingItemId> _resolveSourceBucket({
    required List<TrainingItemId> learnedIds,
    required List<TrainingItemId> unlearnedIds,
  }) {
    if (unlearnedIds.isEmpty && learnedIds.isEmpty) {
      return const <TrainingItemId>[];
    }
    if (unlearnedIds.isEmpty) {
      return learnedIds;
    }
    if (learnedIds.isEmpty) {
      return unlearnedIds;
    }

    final reviewRoll = _random.nextDouble();
    if (reviewRoll < _learningParams.learnedReviewProbability) {
      return learnedIds;
    }
    return unlearnedIds;
  }

  TrainingItemId? _pickWeightedId(
    List<TrainingItemId> candidates,
    Map<TrainingItemId, double> weightById,
  ) {
    if (candidates.isEmpty) return null;

    var totalWeight = 0.0;
    for (final id in candidates) {
      totalWeight += weightById[id] ?? 0.0;
    }

    if (totalWeight <= 0) {
      return candidates[_random.nextInt(candidates.length)];
    }

    var cursor = _random.nextDouble() * totalWeight;
    for (final id in candidates) {
      cursor -= weightById[id] ?? 0.0;
      if (cursor <= 0) return id;
    }

    return candidates.last;
  }

  double _cardWeight(
    TrainingItemId id,
    CardProgress progress, {
    required DateTime now,
    required bool newCardsLimitReached,
    bool applyCooldown = true,
  }) {
    var weight = _learningParams.baseTypeWeight(id.type);

    if (!progress.learned) {
      final targetAccuracy = _learningParams.targetAccuracy(id.type);
      final recentAccuracy = progress.recentAccuracy(
        windowAttempts: _learningParams.recentAttemptsWindow,
      );
      final weakness = (targetAccuracy - recentAccuracy).clamp(0.0, 1.0);
      weight *= 1 + weakness * _learningParams.weaknessBoost;

      if (progress.totalAttempts == 0) {
        weight *= newCardsLimitReached ? 0.05 : _learningParams.newCardBoost;
      }

      if (_lastClusterHadMistake(progress)) {
        weight *= _learningParams.recentMistakeBoost;
      }
    } else {
      weight *= 0.8;
    }

    if (applyCooldown && _isInCooldown(id)) {
      weight *= _learningParams.cooldownPenalty;
    }

    if (weight < 0.0001) {
      return 0.0001;
    }
    return weight;
  }

  bool _lastClusterHadMistake(CardProgress progress) {
    final last = progress.lastCluster;
    if (last == null) return false;
    return last.wrongCount > 0 || last.skippedCount > 0;
  }

  bool _isInCooldown(TrainingItemId id) {
    final cooldown = _learningParams.repeatCooldownCards;
    if (cooldown <= 0 || _recentPickHistory.isEmpty) {
      return false;
    }

    var checked = 0;
    for (
      var i = _recentPickHistory.length - 1;
      i >= 0 && checked < cooldown;
      i -= 1, checked += 1
    ) {
      if (_recentPickHistory[i] == id) {
        return true;
      }
    }
    return false;
  }

  void _rememberPicked(TrainingItemId id) {
    _recentPickHistory.add(id);
    if (_recentPickHistory.length > 64) {
      _recentPickHistory.removeAt(0);
    }
  }

  bool _isDailyNewLimitReached(DateTime now) {
    return _countNewCardsStartedToday(now) >=
        _learningParams.dailyNewCardsLimit;
  }

  int _countNewCardsStartedToday(DateTime now) {
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final endOfDay =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch - 1;

    var count = 0;
    for (final progress in _progressById.values) {
      final firstAttemptAt = progress.firstAttemptAt;
      if (firstAttemptAt < startOfDay || firstAttemptAt > endOfDay) {
        continue;
      }
      count += 1;
    }
    return count;
  }

  int _countAttemptsToday(DateTime now) {
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final endOfDay =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch - 1;

    var attempts = 0;
    for (final progress in _progressById.values) {
      for (final cluster in progress.clusters) {
        final at = cluster.lastAnswerAt;
        if (at < startOfDay || at > endOfDay) {
          continue;
        }
        attempts += cluster.totalAttempts;
      }
    }
    return attempts;
  }
}

class LearningQueueDebugSnapshot {
  const LearningQueueDebugSnapshot({
    required this.language,
    required this.prioritized,
    required this.all,
    required this.weightById,
    required this.progressById,
    required this.dailyAttemptLimit,
    required this.dailyAttemptsToday,
    required this.dailyNewCardsLimit,
    required this.dailyNewCardsToday,
  });

  final LearningLanguage? language;
  final List<TrainingItemId> prioritized;
  final List<TrainingItemId> all;
  final Map<TrainingItemId, double> weightById;
  final Map<TrainingItemId, CardProgress> progressById;
  final int dailyAttemptLimit;
  final int dailyAttemptsToday;
  final int dailyNewCardsLimit;
  final int dailyNewCardsToday;
}
