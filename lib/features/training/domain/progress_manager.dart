import 'dart:math';

import '../data/card_progress.dart';
import '../data/number_cards.dart';
import 'language_router.dart';
import 'learning_language.dart';
import 'repositories.dart';
import 'tasks/number_pronunciation_task.dart';
import 'training_item.dart';

class PickedCard {
  const PickedCard({
    required this.card,
    required this.poolIndex,
  });

  final NumberPronunciationTask card;
  final int poolIndex;
}

class ProgressUpdateResult {
  const ProgressUpdateResult({
    required this.learned,
    required this.poolEmpty,
  });

  final bool learned;
  final bool poolEmpty;
}

class ProgressManager {
  ProgressManager({
    required ProgressRepositoryBase progressRepository,
    required LanguageRouter languageRouter,
    Random? random,
  })  : _progressRepository = progressRepository,
        _languageRouter = languageRouter,
        _random = random ?? Random();

  final ProgressRepositoryBase _progressRepository;
  final LanguageRouter _languageRouter;
  final Random _random;

  Map<TrainingItemId, NumberPronunciationTask> _cardsById = {};
  List<TrainingItemId> _cardIds = [];
  LearningLanguage? _cardsLanguage;

  Map<TrainingItemId, CardProgress> _progressById = {};
  List<TrainingItemId> _pool = [];

  int? _currentPoolIndex;

  LearningLanguage? get cardsLanguage => _cardsLanguage;
  List<TrainingItemId> get cardIds => _cardIds;

  int get totalCards => _cardsById.length;
  int get learnedCount =>
      _progressById.values.where((progress) => progress.learned).length;
  int get remainingCount => totalCards - learnedCount;
  bool get hasRemainingCards => _pool.isNotEmpty;

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
      _pool = [];
      _currentPoolIndex = null;
      return;
    }
    final progress = await _progressRepository.loadAll(
      _cardIds,
      language: language,
    );
    _progressById = {
      for (final id in _cardIds) id: progress[id] ?? CardProgress.empty,
    };
    _pool = [
      for (final id in _cardIds)
        if (!(_progressById[id]?.learned ?? false)) id,
    ]..shuffle(_random);
    _currentPoolIndex = null;
  }

  PickedCard? pickNextCard({
    required bool Function(NumberPronunciationTask card) isEligible,
  }) {
    if (_pool.isEmpty) return null;
    final eligible = <int>[];
    for (var i = 0; i < _pool.length; i += 1) {
      final cardId = _pool[i];
      final card = _cardsById[cardId];
      if (card == null) continue;
      if (isEligible(card)) {
        eligible.add(i);
      }
    }
    if (eligible.isEmpty) return null;
    final poolIndex = eligible[_random.nextInt(eligible.length)];
    _currentPoolIndex = poolIndex;
    final cardId = _pool[poolIndex];
    final card = _cardsById[cardId];
    if (card == null) return null;
    return PickedCard(card: card, poolIndex: poolIndex);
  }

  Future<ProgressUpdateResult> updateProgress({
    required TrainingItemId progressKey,
    required bool isCorrect,
    required LearningLanguage language,
  }) async {
    final progress = _progressById[progressKey] ?? CardProgress.empty;
    final attempts = List<bool>.from(progress.lastAttempts)..add(isCorrect);
    if (attempts.length > 10) {
      attempts.removeRange(0, attempts.length - 10);
    }
    final learned = attempts.length == 10 && attempts.every((value) => value);
    final updated = progress.copyWith(
      learned: learned,
      lastAttempts: attempts,
      totalAttempts: progress.totalAttempts + 1,
      totalCorrect: progress.totalCorrect + (isCorrect ? 1 : 0),
    );
    _progressById[progressKey] = updated;
    await _progressRepository.save(
      progressKey,
      updated,
      language: language,
    );
    if (learned) {
      _removeFromPool();
    }
    return ProgressUpdateResult(
      learned: learned,
      poolEmpty: _pool.isEmpty,
    );
  }

  void resetSelection() {
    _currentPoolIndex = null;
  }

  void _removeFromPool() {
    final index = _currentPoolIndex;
    if (index == null || index >= _pool.length) return;
    final lastIndex = _pool.length - 1;
    _pool[index] = _pool[lastIndex];
    _pool.removeLast();
    _currentPoolIndex = null;
  }
}
