import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/domain/language_router.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/progress_manager.dart';
import 'package:number_gym/features/training/domain/task_availability.dart';
import 'package:number_gym/features/training/domain/task_scheduler.dart';
import 'package:number_gym/features/training/domain/training_catalog.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';
import 'package:number_gym/features/training/domain/tasks/number_pronunciation_task.dart';

import 'helpers/training_fakes.dart';

void main() {
  test('returns paused when forced method and type are incompatible', () async {
    final manager = await _buildManager();
    final scheduler = _buildScheduler();

    final result = await scheduler.scheduleNext(
      progressManager: manager,
      language: LearningLanguage.english,
      premiumPronunciationEnabled: false,
      forcedLearningMethod: LearningMethod.valueToText,
      forcedItemType: TrainingItemType.phone33x3,
    );

    expect(result, isA<TaskSchedulePaused>());
    expect(
      (result as TaskSchedulePaused).errorMessage,
      contains('does not support'),
    );
  });

  test('returns paused when forced phrase mode has no internet', () async {
    final manager = await _buildManager();
    final scheduler = _buildScheduler(hasInternet: false);

    final result = await scheduler.scheduleNext(
      progressManager: manager,
      language: LearningLanguage.english,
      premiumPronunciationEnabled: true,
      forcedLearningMethod: LearningMethod.phrasePronunciation,
      forcedItemType: TrainingItemType.digits,
    );

    expect(result, isA<TaskSchedulePaused>());
    expect(
      (result as TaskSchedulePaused).errorMessage.toLowerCase(),
      contains('internet'),
    );
  });

  test('returns finished when no unlearned cards remain', () async {
    final repository = InMemoryProgressRepository(
      seeded: {
        repoStorageKey(
          _singleCardId,
          LearningLanguage.english,
        ): const CardProgress(
          learned: true,
          clusters: <CardCluster>[],
          learnedAt: 1000,
          firstAttemptAt: 1000,
        ),
      },
    );
    final manager = await _buildManager(repository: repository);
    final scheduler = _buildScheduler();

    final result = await scheduler.scheduleNext(
      progressManager: manager,
      language: LearningLanguage.english,
      premiumPronunciationEnabled: false,
    );

    expect(result, isA<TaskScheduleFinished>());
  });

  test(
    'returns paused when speech is unavailable in forced speech mode',
    () async {
      final manager = await _buildManager();
      final scheduler = _buildScheduler(
        speechService: FakeSpeechService(
          ready: false,
          errorMessage: 'Speech unavailable',
        ),
      );

      final result = await scheduler.scheduleNext(
        progressManager: manager,
        language: LearningLanguage.english,
        premiumPronunciationEnabled: false,
        forcedLearningMethod: LearningMethod.numberPronunciation,
        forcedItemType: TrainingItemType.digits,
      );

      expect(result, isA<TaskSchedulePaused>());
      expect((result as TaskSchedulePaused).errorMessage, contains('Speech'));
    },
  );
}

const TrainingItemId _singleCardId = TrainingItemId(
  type: TrainingItemType.digits,
  number: 7,
);

Future<ProgressManager> _buildManager({
  InMemoryProgressRepository? repository,
}) async {
  final settings = FakeSettingsRepository();
  final manager = ProgressManager(
    progressRepository: repository ?? InMemoryProgressRepository(),
    languageRouter: LanguageRouter(settingsRepository: settings),
    catalog: TrainingCatalog(
      providers: const <TrainingCardProvider>[_SingleCardProvider()],
    ),
  );
  await manager.loadProgress(LearningLanguage.english);
  return manager;
}

TaskScheduler _buildScheduler({
  bool hasInternet = true,
  FakeSpeechService? speechService,
  FakeTtsService? ttsService,
}) {
  final settings = FakeSettingsRepository();
  final availabilityRegistry = TaskAvailabilityRegistry(
    providers: [
      SpeechTaskAvailabilityProvider(speechService ?? FakeSpeechService()),
      TtsTaskAvailabilityProvider(ttsService ?? FakeTtsService()),
      PhraseTaskAvailabilityProvider(),
    ],
  );
  return TaskScheduler(
    languageRouter: LanguageRouter(settingsRepository: settings),
    availabilityRegistry: availabilityRegistry,
    internetChecker: () async => hasInternet,
  );
}

class _SingleCardProvider extends TrainingCardProvider {
  const _SingleCardProvider();

  @override
  List<PronunciationTaskData> buildCards({
    required LearningLanguage language,
    String Function(int p1)? toWords,
  }) {
    return <PronunciationTaskData>[
      NumberPronunciationTask(
        id: _singleCardId,
        numberValue: 7,
        prompt: '7',
        language: language,
        answers: const <String>['seven', '7'],
      ),
    ];
  }
}
