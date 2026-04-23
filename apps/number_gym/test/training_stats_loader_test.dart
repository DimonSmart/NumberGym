import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/daily_session_stats.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/study_streak.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_stats_loader.dart';

import 'helpers/training_fakes.dart';

void main() {
  test(
    'load returns normalized progress, daily stats, and streak snapshot',
    () async {
      final now = DateTime(2026, 2, 10, 14, 15);
      const language = LearningLanguage.english;
      const seededId = TrainingItemId(type: TrainingItemType.timeRandom);
      final progressRepository = InMemoryProgressRepository(
        seeded: {
          repoStorageKey(seededId, language): CardProgress(
            learned: true,
            clusters: <CardCluster>[
              CardCluster(
                lastAnswerAt: now.millisecondsSinceEpoch,
                correctCount: 5,
                wrongCount: 1,
                skippedCount: 0,
              ),
            ],
            learnedAt: now.millisecondsSinceEpoch,
            firstAttemptAt: now.millisecondsSinceEpoch,
            consecutiveCorrect: 4,
          ),
        },
      );
      final settingsRepository = FakeSettingsRepository(
        language: language,
        dailySessionStatsByLanguage: {
          language: DailySessionStats(
            dayKey: '2026-02-10',
            sessionsCompleted: 2,
            cardsCompleted: 18,
            durationSeconds: 540,
          ),
        },
        streakByLanguage: {
          language: StudyStreak(
            sessionsByDay: const <String, int>{
              '2026-02-08': 1,
              '2026-02-09': 1,
              '2026-02-10': 2,
            },
          ),
        },
      );
      final loader = TrainingStatsLoader(
        progressRepository: progressRepository,
        settingsRepository: settingsRepository,
      );

      final snapshot = await loader.load(now: now);

      expect(snapshot.language, language);
      expect(snapshot.progressById.length, snapshot.cardIds.length);
      expect(snapshot.progressById[seededId]!.learned, isTrue);
      expect(snapshot.dailySummary.completedToday, 6);
      expect(snapshot.dailySessionStats.sessionsCompleted, 2);
      expect(snapshot.streakSnapshot.currentStreakDays, 3);
      expect(snapshot.allLearned, isFalse);
    },
  );
}
