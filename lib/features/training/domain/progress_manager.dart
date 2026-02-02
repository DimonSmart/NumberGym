import 'dart:math';

import '../data/card_progress.dart';
import '../data/number_cards.dart';
import 'learning_language.dart';
import 'learning_strategy/learning_params.dart';
import 'learning_strategy/learning_queue.dart';
import 'learning_strategy/learning_state.dart';
import 'learning_strategy/learning_strategy.dart';
import 'language_router.dart';
import 'repositories.dart';
import 'tasks/number_pronunciation_task.dart';
import 'training_item.dart';

class PickedCard {
  const PickedCard({
    required this.card,
  });

  final NumberPronunciationTask card;
}

class ProgressAttemptResult {
  const ProgressAttemptResult({
    required this.learned,
    required this.poolEmpty,
    required this.clusterApplied,
    required this.clusterSuccess,
    required this.countedSuccess,
  });

  final bool learned;
  final bool poolEmpty;
  final bool clusterApplied;
  final bool clusterSuccess;
  final bool countedSuccess;

  static const ProgressAttemptResult none = ProgressAttemptResult(
    learned: false,
    poolEmpty: false,
    clusterApplied: false,
    clusterSuccess: false,
    countedSuccess: false,
  );
}

class ProgressManager {
  ProgressManager({
    required ProgressRepositoryBase progressRepository,
    required LanguageRouter languageRouter,
    LearningParams? learningParams,
    Random? random,
  })  : _progressRepository = progressRepository,
        _languageRouter = languageRouter,
        _random = random ?? Random(),
        _learningParams = learningParams ?? LearningParams.defaults() {
    _queue = LearningQueue(
      allCards: const <TrainingItemId>[],
      activeLimit: _learningParams.activeLimit,
    );
    _learningStrategy = LearningStrategy.defaults(
      queue: _queue,
      params: _learningParams,
    );
  }

  final ProgressRepositoryBase _progressRepository;
  final LanguageRouter _languageRouter;
  final Random _random;
  final LearningParams _learningParams;
  late LearningQueue _queue;
  late LearningStrategy _learningStrategy;

  Map<TrainingItemId, NumberPronunciationTask> _cardsById = {};
  List<TrainingItemId> _cardIds = [];
  LearningLanguage? _cardsLanguage;

  Map<TrainingItemId, CardProgress> _progressById = {};

  LearningLanguage? get cardsLanguage => _cardsLanguage;
  List<TrainingItemId> get cardIds => _cardIds;
  LearningParams get learningParams => _learningParams;
  int get activeCount => _queue.activeCount;
  int get backlogCount => _queue.backlogCount;

  int get totalCards => _cardsById.length;
  int get learnedCount =>
      _progressById.values.where((progress) => progress.learned).length;
  int get remainingCount => totalCards - learnedCount;
  bool get hasRemainingCards => _queue.hasRemaining;

  NumberPronunciationTask? cardById(TrainingItemId id) => _cardsById[id];

  void refreshCardsIfNeeded(LearningLanguage language) {
    if (_cardsLanguage == language && _cardsById.isNotEmpty) return;
    _cardsLanguage = language;
    final toWords = _languageRouter.numberWordsConverter(language);
    final cards = buildNumberCards(
      language: language,
      toWords: toWords,
    );
    _cardsById = {for (final card in cards) card.id: card};
    _cardIds = _cardsById.keys.toList()..sort();
  }

  Future<void> loadProgress(LearningLanguage language) async {
    refreshCardsIfNeeded(language);
    if (_cardIds.isEmpty) {
      _progressById = {};
      _queue = LearningQueue(
        allCards: const <TrainingItemId>[],
        activeLimit: _learningParams.activeLimit,
      );
      _learningStrategy = LearningStrategy.defaults(
        queue: _queue,
        params: _learningParams,
      );
      return;
    }
    final progress = await _progressRepository.loadAll(
      _cardIds,
      language: language,
    );
    _progressById = {
      for (final id in _cardIds) id: progress[id] ?? CardProgress.empty,
    };
    final unlearned = <TrainingItemId>[
      for (final id in _cardIds)
        if (!(_progressById[id]?.learned ?? false)) id,
    ];
    _queue = LearningQueue(
      allCards: _cardIds,
      activeLimit: _learningParams.activeLimit,
    );
    _queue.reset(unlearned: unlearned);
    _learningStrategy = LearningStrategy.defaults(
      queue: _queue,
      params: _learningParams,
    );
  }

  PickedCard? pickNextCard({
    required bool Function(NumberPronunciationTask card) isEligible,
    DateTime? now,
  }) {
    if (_cardIds.isEmpty) return null;
    final resolvedNow = now ?? DateTime.now();
    final candidateStates = _learningStrategy.pickNextStates(
      now: resolvedNow,
      limit: _cardIds.length,
      progressById: _progressById,
      isEligible: (id) {
        final card = _cardsById[id];
        if (card == null) return false;
        return isEligible(card);
      },
    );
    if (candidateStates.isEmpty) return null;
    final nowMillis = resolvedNow.millisecondsSinceEpoch;
    int resolvedDue(LearningState state) {
      final due = state.progress.nextDue;
      return due > 0 ? due : nowMillis;
    }

    final earliestDue = resolvedDue(candidateStates.first);
    final earliestIds = <TrainingItemId>[];
    for (final state in candidateStates) {
      if (resolvedDue(state) != earliestDue) break;
      if (_cardsById.containsKey(state.id)) {
        earliestIds.add(state.id);
      }
    }

    final pickedId = earliestIds.isEmpty
        ? candidateStates.first.id
        : earliestIds[_random.nextInt(earliestIds.length)];
    final pickedCard = _cardsById[pickedId];
    if (pickedCard == null) return null;
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
    var progress = _progressById[progressKey] ?? CardProgress.empty;
    final clusters = List<CardCluster>.from(progress.clusters);
    final lastCluster = clusters.isEmpty ? null : clusters.last;
    final gapMinutes = _learningParams.clusterMaxGapMinutes;
    final updatedClusters = List<CardCluster>.from(clusters);
    final updatedLastAnswerAt = timestamp.millisecondsSinceEpoch;
    if (lastCluster != null && lastCluster.lastAnswerAt > 0) {
      final withinGap = timestamp.difference(
            DateTime.fromMillisecondsSinceEpoch(
              lastCluster.lastAnswerAt,
            ),
          ) <=
          Duration(minutes: gapMinutes);
      if (withinGap) {
        final updatedCluster = _updateCluster(
          lastCluster,
          isCorrect: isCorrect,
          isSkipped: isSkipped,
          lastAnswerAt: updatedLastAnswerAt,
        );
        updatedClusters[updatedClusters.length - 1] = updatedCluster;
      } else {
        updatedClusters.add(
          CardCluster(
            lastAnswerAt: updatedLastAnswerAt,
            correctCount: isCorrect ? 1 : 0,
            wrongCount: (!isCorrect && !isSkipped) ? 1 : 0,
            skippedCount: isSkipped ? 1 : 0,
          ),
        );
      }
    } else {
      updatedClusters.add(
        CardCluster(
          lastAnswerAt: updatedLastAnswerAt,
          correctCount: isCorrect ? 1 : 0,
          wrongCount: (!isCorrect && !isSkipped) ? 1 : 0,
          skippedCount: isSkipped ? 1 : 0,
        ),
      );
    }
    final maxClusters = _learningParams.maxStoredClusters;
    if (updatedClusters.length > maxClusters) {
      final overflow = updatedClusters.length - maxClusters;
      updatedClusters.removeRange(0, overflow);
    }

    final attemptAccuracy = isCorrect ? 1.0 : 0.0;
    final result = _learningStrategy.applyClusterResult(
      itemId: progressKey,
      progress: progress,
      accuracy: attemptAccuracy,
      now: timestamp,
    );
    progress = result.progress;
    if (result.learnedNow && progress.learnedAt == 0) {
      progress = progress.copyWith(
        learnedAt: timestamp.millisecondsSinceEpoch,
      );
    }
    final attemptResult = ProgressAttemptResult(
      learned: result.learnedNow,
      poolEmpty: !_queue.hasRemaining,
      clusterApplied: true,
      clusterSuccess: result.clusterSuccess,
      countedSuccess: result.countedSuccess,
    );

    final updated = progress.copyWith(clusters: updatedClusters);
    _progressById[progressKey] = updated;
    await _progressRepository.save(
      progressKey,
      updated,
      language: language,
    );
    return attemptResult;
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
    // No-op: selection is handled by the learning strategy.
  }
}
