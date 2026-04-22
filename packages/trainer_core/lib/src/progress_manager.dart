import 'dart:math';

import 'daily_study_summary.dart';
import 'exercise_models.dart';
import 'learning_params.dart';
import 'trainer_repositories.dart';
import 'training/data/card_progress.dart';
import 'training/domain/learning_language.dart';

class ProgressAttemptResult {
  const ProgressAttemptResult({
    required this.learned,
    required this.newCluster,
  });

  final bool learned;
  final bool newCluster;
}

class LearningQueueDebugSnapshot {
  const LearningQueueDebugSnapshot({
    required this.language,
    required this.prioritized,
    required this.all,
    required this.weightByKey,
    required this.progressByKey,
    required this.dailyAttemptLimit,
    required this.dailyAttemptsToday,
    required this.dailyNewCardsLimit,
    required this.dailyNewCardsToday,
  });

  final LearningLanguage language;
  final List<ExerciseCard> prioritized;
  final List<ExerciseCard> all;
  final Map<String, double> weightByKey;
  final Map<String, CardProgress> progressByKey;
  final int dailyAttemptLimit;
  final int dailyAttemptsToday;
  final int dailyNewCardsLimit;
  final int dailyNewCardsToday;
}

class ProgressManager {
  ProgressManager({
    required ProgressRepositoryBase progressRepository,
    required ExerciseCatalog catalog,
    LearningParams? learningParams,
    Random? random,
  }) : _progressRepository = progressRepository,
       _catalog = catalog,
       _learningParams = learningParams ?? LearningParams.defaults(),
       _random = random ?? Random();

  final ProgressRepositoryBase _progressRepository;
  final ExerciseCatalog _catalog;
  final LearningParams _learningParams;
  final Random _random;

  List<ExerciseCard> _cards = const <ExerciseCard>[];
  final Map<String, ExerciseCard> _cardsByProgressKey =
      <String, ExerciseCard>{};
  final Map<String, CardProgress> _progressByKey = <String, CardProgress>{};
  final List<String> _recentPickHistory = <String>[];
  LearningLanguage? _cardsLanguage;

  LearningLanguage? get cardsLanguage => _cardsLanguage;
  List<ExerciseCard> get cards => _cards;

  int get totalCards => _cards.length;
  int get learnedCount =>
      _progressByKey.values.where((progress) => progress.learned).length;
  int get remainingCount => totalCards - learnedCount;
  bool get hasRemainingCards {
    for (final card in _cards) {
      if (!(progressFor(card.progressId).learned)) {
        return true;
      }
    }
    return false;
  }

  CardProgress progressFor(ExerciseId id) {
    return _progressByKey[id.storageKey] ?? CardProgress.empty;
  }

  int hintVisibleUntilCorrectStreak(ExerciseFamily family) {
    return _learningParams.hintVisibleUntilCorrectStreakForFamily(family);
  }

  void refreshCardsIfNeeded(LearningLanguage language) {
    if (_cardsLanguage == language && _cards.isNotEmpty) {
      return;
    }
    final snapshot = _catalog.build(language);
    _cardsLanguage = language;
    _cards = snapshot.cards;
    _cardsByProgressKey
      ..clear()
      ..addEntries(
        _cards.map((card) => MapEntry(card.progressId.storageKey, card)),
      );
  }

  Future<void> loadProgress(LearningLanguage language) async {
    refreshCardsIfNeeded(language);
    final storageKeys = _cards
        .map((card) => card.progressId.storageKey)
        .toList();
    if (storageKeys.isEmpty) {
      _progressByKey.clear();
      _recentPickHistory.clear();
      return;
    }
    final progress = await _progressRepository.loadAll(
      storageKeys,
      language: language,
    );
    _progressByKey
      ..clear()
      ..addAll(progress);
    _recentPickHistory.clear();
  }

  DailyStudySummary dailySummary({DateTime? now}) {
    return DailyStudySummary.fromProgress(
      _progressByKey.values,
      now: now,
      dailyAttemptLimit: _learningParams.dailyAttemptLimit,
      dailyNewCardsLimit: _learningParams.dailyNewCardsLimit,
    );
  }

  ExerciseCard? pickNextCard({
    required bool Function(ExerciseCard card) isEligible,
    DateTime? now,
  }) {
    if (_cards.isEmpty) {
      return null;
    }
    final resolvedNow = now ?? DateTime.now();
    var unlearnedCards = _cards.where((card) {
      if (!isEligible(card)) {
        return false;
      }
      return !(progressFor(card.progressId).learned);
    }).toList();
    if (unlearnedCards.isEmpty) {
      return null;
    }

    final newCardsLimitReached = _isDailyNewLimitReached(resolvedNow);
    if (newCardsLimitReached) {
      final practiced = unlearnedCards.where((card) {
        return progressFor(card.progressId).totalAttempts > 0;
      }).toList();
      if (practiced.isNotEmpty) {
        unlearnedCards = practiced;
      }
    }

    final weightByKey = <String, double>{};
    for (final card in unlearnedCards) {
      final progress = progressFor(card.progressId);
      weightByKey[card.progressId.storageKey] = _cardWeight(
        card,
        progress,
        now: resolvedNow,
        newCardsLimitReached: newCardsLimitReached,
      );
    }
    final picked = _pickWeightedCard(unlearnedCards, weightByKey);
    if (picked == null) {
      return null;
    }
    _rememberPicked(picked.progressId.storageKey);
    return picked;
  }

  Future<ProgressAttemptResult> recordAttempt({
    required ExerciseId progressKey,
    required bool isCorrect,
    required bool isSkipped,
    required LearningLanguage language,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final key = progressKey.storageKey;
    final progress = _progressByKey[key] ?? CardProgress.empty;
    final clusters = List<CardCluster>.from(progress.clusters);
    final updatedLastAnswerAt = timestamp.millisecondsSinceEpoch;
    final lastCluster = clusters.isEmpty ? null : clusters.last;

    final withinGap =
        lastCluster != null &&
        lastCluster.lastAnswerAt > 0 &&
        timestamp.difference(
              DateTime.fromMillisecondsSinceEpoch(lastCluster.lastAnswerAt),
            ) <=
            Duration(minutes: _learningParams.clusterMaxGapMinutes);

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

    if (clusters.length > _learningParams.maxStoredClusters) {
      clusters.removeRange(
        0,
        clusters.length - _learningParams.maxStoredClusters,
      );
    }

    var updated = progress.copyWith(
      clusters: clusters,
      consecutiveCorrect: isCorrect ? progress.consecutiveCorrect + 1 : 0,
    );
    if (updated.firstAttemptAt == 0) {
      updated = updated.copyWith(firstAttemptAt: updatedLastAnswerAt);
    }

    final family = _cardsByProgressKey[key]?.family;
    final wasLearned = progress.learned;
    final isLearnedNow = family != null && _meetsMastery(family, updated);
    updated = updated.copyWith(
      learned: isLearnedNow,
      learnedAt: isLearnedNow
          ? (updated.learnedAt > 0 ? updated.learnedAt : updatedLastAnswerAt)
          : 0,
    );

    _progressByKey[key] = updated;
    await _progressRepository.save(key, updated, language: language);
    return ProgressAttemptResult(
      learned: !wasLearned && isLearnedNow,
      newCluster: createdNewCluster,
    );
  }

  LearningQueueDebugSnapshot debugQueueSnapshot({DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final newCardsLimitReached = _isDailyNewLimitReached(resolvedNow);
    final unlearned = _cards
        .where((card) => !(progressFor(card.progressId).learned))
        .toList();
    final weightByKey = <String, double>{};
    for (final card in unlearned) {
      weightByKey[card.progressId.storageKey] = _cardWeight(
        card,
        progressFor(card.progressId),
        now: resolvedNow,
        newCardsLimitReached: newCardsLimitReached,
        applyCooldown: false,
      );
    }
    final prioritized = unlearned.toList()
      ..sort((left, right) {
        final leftWeight = weightByKey[left.progressId.storageKey] ?? 0;
        final rightWeight = weightByKey[right.progressId.storageKey] ?? 0;
        final diff = rightWeight.compareTo(leftWeight);
        if (diff != 0) {
          return diff;
        }
        return left.progressId.compareTo(right.progressId);
      });

    return LearningQueueDebugSnapshot(
      language: _cardsLanguage ?? LearningLanguage.english,
      prioritized: prioritized.take(60).toList(),
      all: _cards,
      weightByKey: weightByKey,
      progressByKey: Map<String, CardProgress>.unmodifiable(_progressByKey),
      dailyAttemptLimit: _learningParams.dailyAttemptLimit,
      dailyAttemptsToday: _countAttemptsToday(resolvedNow),
      dailyNewCardsLimit: _learningParams.dailyNewCardsLimit,
      dailyNewCardsToday: _countNewCardsStartedToday(resolvedNow),
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

  bool _meetsMastery(ExerciseFamily family, CardProgress progress) {
    if (progress.totalAttempts < _learningParams.minAttemptsToLearn) {
      return false;
    }
    final accuracy = progress.recentAccuracy(
      windowAttempts: _learningParams.recentAttemptsWindow,
    );
    return accuracy >= _learningParams.targetAccuracyForFamily(family);
  }

  ExerciseCard? _pickWeightedCard(
    List<ExerciseCard> cards,
    Map<String, double> weightByKey,
  ) {
    if (cards.isEmpty) {
      return null;
    }
    var total = 0.0;
    for (final card in cards) {
      total += weightByKey[card.progressId.storageKey] ?? 0;
    }
    if (total <= 0) {
      return cards[_random.nextInt(cards.length)];
    }
    var cursor = _random.nextDouble() * total;
    for (final card in cards) {
      cursor -= weightByKey[card.progressId.storageKey] ?? 0;
      if (cursor <= 0) {
        return card;
      }
    }
    return cards.last;
  }

  double _cardWeight(
    ExerciseCard card,
    CardProgress progress, {
    required DateTime now,
    required bool newCardsLimitReached,
    bool applyCooldown = true,
  }) {
    var weight = _learningParams.baseTypeWeight(card.family.difficultyTier);
    if (!progress.learned) {
      final targetAccuracy = _learningParams.targetAccuracyForFamily(
        card.family,
      );
      final recentAccuracy = progress.recentAccuracy(
        windowAttempts: _learningParams.recentAttemptsWindow,
      );
      final weakness = (targetAccuracy - recentAccuracy).clamp(0.0, 1.0);
      weight *= 1 + weakness * _learningParams.weaknessBoost;

      if (progress.totalAttempts == 0) {
        weight *= newCardsLimitReached ? 0.05 : _learningParams.newCardBoost;
      }

      final last = progress.lastCluster;
      if (last != null && (last.wrongCount > 0 || last.skippedCount > 0)) {
        weight *= _learningParams.recentMistakeBoost;
      }
    } else {
      weight *= 0.8;
    }

    if (applyCooldown && _isInCooldown(card.progressId.storageKey)) {
      weight *= _learningParams.cooldownPenalty;
    }
    return weight < 0.0001 ? 0.0001 : weight;
  }

  bool _isInCooldown(String storageKey) {
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
      if (_recentPickHistory[i] == storageKey) {
        return true;
      }
    }
    return false;
  }

  void _rememberPicked(String storageKey) {
    _recentPickHistory.add(storageKey);
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
    for (final progress in _progressByKey.values) {
      final firstAttemptAt = progress.firstAttemptAt;
      if (firstAttemptAt >= startOfDay && firstAttemptAt <= endOfDay) {
        count += 1;
      }
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
    for (final progress in _progressByKey.values) {
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
