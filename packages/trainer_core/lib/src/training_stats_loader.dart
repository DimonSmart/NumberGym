import 'daily_study_summary.dart';
import 'exercise_models.dart';
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
    required this.dailySummary,
    required this.dailySessionStats,
    required this.streakSnapshot,
  }) : cards = List<ExerciseCard>.unmodifiable(cards),
       progressById = Map<ExerciseId, CardProgress>.unmodifiable(progressById),
       familyProgress = _buildFamilyProgress(cards, progressById);

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
    required List<TrainingStatsConceptProgress> concepts,
  }) : concepts = List<TrainingStatsConceptProgress>.unmodifiable(concepts);

  final ExerciseFamily family;
  final int totalCards;
  final int learnedCards;
  final List<TrainingStatsConceptProgress> concepts;

  int get totalConcepts => concepts.length;
  int get learnedConcepts =>
      concepts.where((concept) => concept.learned).length;
}

class TrainingStatsConceptProgress {
  const TrainingStatsConceptProgress({
    required this.concept,
    required this.totalCards,
    required this.learnedCards,
  });

  final ExerciseConcept concept;
  final int totalCards;
  final int learnedCards;

  bool get learned => totalCards > 0 && learnedCards == totalCards;
  double get progressValue {
    if (totalCards <= 0) {
      return 0;
    }
    return learnedCards / totalCards;
  }
}

class TrainingStatsLoader {
  TrainingStatsLoader({
    required ProgressRepositoryBase progressRepository,
    required SettingsRepositoryBase settingsRepository,
    required ExerciseCatalog catalog,
    StudyStreakService? studyStreakService,
  }) : _progressRepository = progressRepository,
       _settingsRepository = settingsRepository,
       _catalog = catalog,
       _studyStreakService =
           studyStreakService ??
           StudyStreakService(settingsRepository: settingsRepository);

  final ProgressRepositoryBase _progressRepository;
  final SettingsRepositoryBase _settingsRepository;
  final ExerciseCatalog _catalog;
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
) {
  final familiesByKey = <String, _FamilyProgressBuilder>{};
  for (final card in cards) {
    final familyKey = card.family.storageKey;
    final family = familiesByKey.putIfAbsent(
      familyKey,
      () => _FamilyProgressBuilder(card.family),
    );
    final learned = progressById[card.progressId]?.learned ?? false;
    family.totalCards += 1;
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
      concepts: concepts,
    );
  }
}

class _ConceptProgressBuilder {
  _ConceptProgressBuilder(this.concept);

  final ExerciseConcept concept;
  int totalCards = 0;
  int learnedCards = 0;

  TrainingStatsConceptProgress build() {
    return TrainingStatsConceptProgress(
      concept: concept,
      totalCards: totalCards,
      learnedCards: learnedCards,
    );
  }
}
