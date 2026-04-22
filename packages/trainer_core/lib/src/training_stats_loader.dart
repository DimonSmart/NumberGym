import 'daily_study_summary.dart';
import 'exercise_models.dart';
import 'study_streak_service.dart';
import 'trainer_repositories.dart';
import 'training/domain/learning_language.dart';
import 'training/data/card_progress.dart';

class TrainingStatsSnapshot {
  TrainingStatsSnapshot({
    required this.language,
    required List<ExerciseCard> cards,
    required Map<ExerciseId, CardProgress> progressById,
    required this.dailySummary,
    required this.dailySessionStats,
    required this.streakSnapshot,
  }) : cards = List<ExerciseCard>.unmodifiable(cards),
       progressById = Map<ExerciseId, CardProgress>.unmodifiable(progressById);

  final LearningLanguage language;
  final List<ExerciseCard> cards;
  final Map<ExerciseId, CardProgress> progressById;
  final DailyStudySummary dailySummary;
  final DailySessionStats dailySessionStats;
  final StudyStreakSnapshot streakSnapshot;

  int get totalCards => cards.length;
  int get learnedCount => progressById.values.where((progress) => progress.learned).length;
  bool get allLearned => totalCards > 0 && learnedCount == totalCards;
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
    final language = _settingsRepository.readLearningLanguage();
    final snapshot = _catalog.build(language);
    final storageKeys = snapshot.cards.map((card) => card.progressId.storageKey).toList();
    final rawProgress = await _progressRepository.loadAll(
      storageKeys,
      language: language,
    );
    final progressById = <ExerciseId, CardProgress>{
      for (final card in snapshot.cards)
        card.progressId: rawProgress[card.progressId.storageKey] ?? CardProgress.empty,
    };

    return TrainingStatsSnapshot(
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
