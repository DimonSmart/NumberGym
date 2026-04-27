import 'card_learning_progress.dart';
import 'daily_study_summary.dart';
import 'exercise_models.dart';
import 'learning_params.dart';
import 'study_streak_service.dart';
import 'trainer_repositories.dart';
import 'training/domain/learning_language.dart';
import 'training/data/card_progress.dart';

class TrainingStatsSnapshot {
  TrainingStatsSnapshot({
    required this.baseLanguage,
    required this.language,
    required List<ExerciseCard> cards,
    required Map<ExerciseId, CardProgress> progressById,
    required LearningParams learningParams,
    required this.dailySummary,
    required this.dailySessionStats,
    required this.streakSnapshot,
  }) : cards = List<ExerciseCard>.unmodifiable(cards),
       progressById = Map<ExerciseId, CardProgress>.unmodifiable(progressById),
       familyProgress = _buildFamilyProgress(
         cards,
         progressById,
         learningParams,
       );

  final LearningLanguage baseLanguage;
  final LearningLanguage language;
  final List<ExerciseCard> cards;
  final Map<ExerciseId, CardProgress> progressById;
  final List<TrainingStatsFamilyProgress> familyProgress;
  final DailyStudySummary dailySummary;
  final DailySessionStats dailySessionStats;
  final StudyStreakSnapshot streakSnapshot;

  int get totalCards => cards.length;
  int get learnedCount =>
      progressById.values.where((progress) => progress.learned).length;
  bool get allLearned => totalCards > 0 && learnedCount == totalCards;
  int get totalConcepts =>
      familyProgress.fold(0, (total, family) => total + family.totalConcepts);
  int get learnedConceptCount =>
      familyProgress.fold(0, (total, family) => total + family.learnedConcepts);
  bool get hasConceptProgress => totalConcepts > 0;
}

class TrainingStatsFamilyProgress {
  TrainingStatsFamilyProgress({
    required this.family,
    required this.totalCards,
    required this.learnedCards,
    required this.totalCorrect,
    required this.totalAttempts,
    required this.creditedCorrectAttempts,
    required this.requiredCorrectAttempts,
    required List<TrainingStatsConceptProgress> concepts,
  }) : concepts = List<TrainingStatsConceptProgress>.unmodifiable(concepts);

  final ExerciseFamily family;
  final int totalCards;
  final int learnedCards;
  final int totalCorrect;
  final int totalAttempts;
  final int creditedCorrectAttempts;
  final int requiredCorrectAttempts;
  final List<TrainingStatsConceptProgress> concepts;

  int get totalConcepts => concepts.length;
  int get learnedConcepts =>
      concepts.where((concept) => concept.learned).length;
}

class TrainingStatsConceptProgress {
  TrainingStatsConceptProgress({
    required this.concept,
    required this.totalCards,
    required this.learnedCards,
    required this.totalCorrect,
    required this.totalAttempts,
    required this.creditedCorrectAttempts,
    required this.requiredCorrectAttempts,
    required List<TrainingStatsCardProgress> cards,
  }) : cards = List<TrainingStatsCardProgress>.unmodifiable(cards);

  final ExerciseConcept concept;
  final int totalCards;
  final int learnedCards;
  final int totalCorrect;
  final int totalAttempts;
  final int creditedCorrectAttempts;
  final int requiredCorrectAttempts;
  final List<TrainingStatsCardProgress> cards;

  bool get learned => totalCards > 0 && learnedCards == totalCards;
  double get progressValue {
    if (requiredCorrectAttempts <= 0) {
      return 0;
    }
    return creditedCorrectAttempts / requiredCorrectAttempts;
  }
}

class TrainingStatsCardProgress {
  const TrainingStatsCardProgress({
    required this.card,
    required this.progress,
    required this.learningProgress,
  });

  final ExerciseCard card;
  final CardProgress progress;
  final CardLearningProgress learningProgress;

  bool get learned => progress.learned;
}

class TrainingStatsLoader {
  TrainingStatsLoader({
    required ProgressRepositoryBase progressRepository,
    required SettingsRepositoryBase settingsRepository,
    required ExerciseCatalog catalog,
    LearningParams? learningParams,
    StudyStreakService? studyStreakService,
  }) : _progressRepository = progressRepository,
       _settingsRepository = settingsRepository,
       _catalog = catalog,
       _learningParams = learningParams ?? LearningParams.defaults(),
       _studyStreakService =
           studyStreakService ??
           StudyStreakService(settingsRepository: settingsRepository);

  final ProgressRepositoryBase _progressRepository;
  final SettingsRepositoryBase _settingsRepository;
  final ExerciseCatalog _catalog;
  final LearningParams _learningParams;
  final StudyStreakService _studyStreakService;

  Future<TrainingStatsSnapshot> load({DateTime? now}) async {
    final resolvedNow = now ?? DateTime.now();
    final baseLanguage = _settingsRepository.readBaseLanguage();
    final language = _settingsRepository.readLearningLanguage();
    final snapshot = _catalog.build(language, baseLanguage: baseLanguage);
    final storageKeys = snapshot.cards
        .map((card) => card.progressId.storageKey)
        .toList();
    final rawProgress = await _progressRepository.loadAll(
      storageKeys,
      language: language,
    );
    final progressById = <ExerciseId, CardProgress>{
      for (final card in snapshot.cards)
        card.progressId:
            rawProgress[card.progressId.storageKey] ?? CardProgress.empty,
    };

    return TrainingStatsSnapshot(
      baseLanguage: baseLanguage,
      language: language,
      cards: snapshot.cards,
      progressById: progressById,
      learningParams: _learningParams,
      dailySummary: DailyStudySummary.fromProgress(
        progressById.values,
        now: resolvedNow,
      ),
      dailySessionStats: _settingsRepository.readDailySessionStats(
        now: resolvedNow,
      ),
      streakSnapshot: _studyStreakService.readCurrentStreakSnapshot(
        now: resolvedNow,
      ),
    );
  }
}

List<TrainingStatsFamilyProgress> _buildFamilyProgress(
  List<ExerciseCard> cards,
  Map<ExerciseId, CardProgress> progressById,
  LearningParams learningParams,
) {
  final familiesByKey = <String, _FamilyProgressBuilder>{};
  for (final card in cards) {
    final familyKey = card.family.storageKey;
    final family = familiesByKey.putIfAbsent(
      familyKey,
      () => _FamilyProgressBuilder(card.family),
    );
    final progress = progressById[card.progressId] ?? CardProgress.empty;
    final learned = progress.learned;
    final cardLearningProgress = CardLearningProgress.forCard(
      family: card.family,
      progress: progress,
      learningParams: learningParams,
    );
    family.totalCards += 1;
    family.totalCorrect += progress.totalCorrect;
    family.totalAttempts += progress.totalAttempts;
    family.creditedCorrectAttempts +=
        cardLearningProgress.creditedCorrectAttempts;
    family.requiredCorrectAttempts +=
        cardLearningProgress.requiredCorrectAttempts;
    if (learned) {
      family.learnedCards += 1;
    }

    final concept = card.concept;
    if (concept == null) {
      continue;
    }
    final conceptProgress = family.conceptsById.putIfAbsent(
      concept.id,
      () => _ConceptProgressBuilder(concept),
    );
    conceptProgress.totalCards += 1;
    conceptProgress.totalCorrect += progress.totalCorrect;
    conceptProgress.totalAttempts += progress.totalAttempts;
    conceptProgress.creditedCorrectAttempts +=
        cardLearningProgress.creditedCorrectAttempts;
    conceptProgress.requiredCorrectAttempts +=
        cardLearningProgress.requiredCorrectAttempts;
    conceptProgress.cards.add(
      TrainingStatsCardProgress(
        card: card,
        progress: progress,
        learningProgress: cardLearningProgress,
      ),
    );
    if (learned) {
      conceptProgress.learnedCards += 1;
    }
  }

  return familiesByKey.values.map((family) => family.build()).toList()
    ..sort((left, right) => left.family.label.compareTo(right.family.label));
}

class _FamilyProgressBuilder {
  _FamilyProgressBuilder(this.family);

  final ExerciseFamily family;
  final Map<String, _ConceptProgressBuilder> conceptsById =
      <String, _ConceptProgressBuilder>{};
  int totalCards = 0;
  int learnedCards = 0;
  int totalCorrect = 0;
  int totalAttempts = 0;
  int creditedCorrectAttempts = 0;
  int requiredCorrectAttempts = 0;

  TrainingStatsFamilyProgress build() {
    final concepts =
        conceptsById.values.map((concept) => concept.build()).toList()..sort(
          (left, right) =>
              left.concept.baseLabel.compareTo(right.concept.baseLabel),
        );
    return TrainingStatsFamilyProgress(
      family: family,
      totalCards: totalCards,
      learnedCards: learnedCards,
      totalCorrect: totalCorrect,
      totalAttempts: totalAttempts,
      creditedCorrectAttempts: creditedCorrectAttempts,
      requiredCorrectAttempts: requiredCorrectAttempts,
      concepts: concepts,
    );
  }
}

class _ConceptProgressBuilder {
  _ConceptProgressBuilder(this.concept);

  final ExerciseConcept concept;
  int totalCards = 0;
  int learnedCards = 0;
  int totalCorrect = 0;
  int totalAttempts = 0;
  int creditedCorrectAttempts = 0;
  int requiredCorrectAttempts = 0;
  final List<TrainingStatsCardProgress> cards = <TrainingStatsCardProgress>[];

  TrainingStatsConceptProgress build() {
    final sortedCards = List<TrainingStatsCardProgress>.from(cards)
      ..sort((left, right) => left.card.id.compareTo(right.card.id));
    return TrainingStatsConceptProgress(
      concept: concept,
      totalCards: totalCards,
      learnedCards: learnedCards,
      totalCorrect: totalCorrect,
      totalAttempts: totalAttempts,
      creditedCorrectAttempts: creditedCorrectAttempts,
      requiredCorrectAttempts: requiredCorrectAttempts,
      cards: sortedCards,
    );
  }
}
