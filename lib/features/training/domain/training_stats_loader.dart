import '../data/card_progress.dart';
import '../data/number_cards.dart';
import 'daily_session_stats.dart';
import 'daily_study_summary.dart';
import 'learning_language.dart';
import 'repositories.dart';
import 'study_streak_service.dart';
import 'training_item.dart';

class TrainingStatsSnapshot {
  TrainingStatsSnapshot({
    required this.language,
    required List<TrainingItemId> cardIds,
    required Map<TrainingItemId, CardProgress> progressById,
    required this.dailySummary,
    required this.dailySessionStats,
    required this.streakSnapshot,
  }) : cardIds = List<TrainingItemId>.unmodifiable(cardIds),
       progressById = Map<TrainingItemId, CardProgress>.unmodifiable(
         progressById,
       );

  final LearningLanguage language;
  final List<TrainingItemId> cardIds;
  final Map<TrainingItemId, CardProgress> progressById;
  final DailyStudySummary dailySummary;
  final DailySessionStats dailySessionStats;
  final StudyStreakSnapshot streakSnapshot;

  int get totalCards => cardIds.length;

  int get learnedCount => progressById.values.where((it) => it.learned).length;

  bool get allLearned => totalCards > 0 && learnedCount == totalCards;
}

class TrainingStatsLoader {
  TrainingStatsLoader({
    required ProgressRepositoryBase progressRepository,
    required SettingsRepositoryBase settingsRepository,
    StudyStreakService? studyStreakService,
  }) : _progressRepository = progressRepository,
       _settingsRepository = settingsRepository,
       _studyStreakService =
           studyStreakService ??
           StudyStreakService(settingsRepository: settingsRepository);

  final ProgressRepositoryBase _progressRepository;
  final SettingsRepositoryBase _settingsRepository;
  final StudyStreakService _studyStreakService;

  Future<TrainingStatsSnapshot> load({DateTime? now}) async {
    final resolvedNow = now ?? DateTime.now();
    final language = _settingsRepository.readLearningLanguage();
    final cardIds = buildAllCardIds();
    final rawProgress = await _progressRepository.loadAll(
      cardIds,
      language: language,
    );
    final progressById = <TrainingItemId, CardProgress>{
      for (final id in cardIds) id: rawProgress[id] ?? CardProgress.empty,
    };

    return TrainingStatsSnapshot(
      language: language,
      cardIds: cardIds,
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
