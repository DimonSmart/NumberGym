import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  late Directory tempDir;
  late Box<CardProgress> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('progress_repo_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CardProgressAdapter());
    }
  });

  setUp(() async {
    box = await Hive.openBox<CardProgress>('progress_test');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('progress_test');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('loadAll returns entries for provided storage keys', () async {
    final repo = ProgressRepository(box);
    final ids = <ExerciseId>[
      const ExerciseId(moduleId: 'test', familyId: 'digits', variantId: '0'),
      const ExerciseId(moduleId: 'test', familyId: 'digits', variantId: '1'),
      const ExerciseId(moduleId: 'test', familyId: 'digits', variantId: '2'),
    ];
    final keys = ids.map((id) => id.storageKey).toList();
    final results = await repo.loadAll(keys, language: LearningLanguage.english);

    expect(results.length, keys.length);
    expect(results.keys, containsAll(keys));
    expect(results[keys[0]]!.totalAttempts, 0);
    expect(results[keys[0]]!.totalCorrect, 0);
  });

  test('save persists progress', () async {
    final repo = ProgressRepository(box);
    const progress = CardProgress(
      learned: true,
      clusters: <CardCluster>[
        CardCluster(
          lastAnswerAt: 1000,
          correctCount: 4,
          wrongCount: 1,
          skippedCount: 0,
        ),
      ],
      learnedAt: 1000,
      firstAttemptAt: 800,
      consecutiveCorrect: 4,
    );

    const targetId = ExerciseId(
      moduleId: 'test',
      familyId: 'digits',
      variantId: '2',
    );
    await repo.save(
      targetId.storageKey,
      progress,
      language: LearningLanguage.english,
    );
    final keys = [
      const ExerciseId(moduleId: 'test', familyId: 'digits', variantId: '0')
          .storageKey,
      const ExerciseId(moduleId: 'test', familyId: 'digits', variantId: '1')
          .storageKey,
      targetId.storageKey,
    ];
    final results = await repo.loadAll(keys, language: LearningLanguage.english);
    final stored = results[targetId.storageKey]!;

    expect(stored.learned, true);
    expect(stored.totalAttempts, 5);
    expect(stored.totalCorrect, 4);
    expect(stored.clusters.length, 1);
    expect(stored.learnedAt, 1000);
    expect(stored.firstAttemptAt, 800);
    expect(stored.consecutiveCorrect, 4);
  });

  test('reset clears progress for language', () async {
    final repo = ProgressRepository(box);
    const progress = CardProgress(
      learned: false,
      clusters: <CardCluster>[
        CardCluster(
          lastAnswerAt: 2000,
          correctCount: 1,
          wrongCount: 0,
          skippedCount: 0,
        ),
      ],
      learnedAt: 0,
      firstAttemptAt: 2000,
    );

    const targetId = ExerciseId(
      moduleId: 'test',
      familyId: 'digits',
      variantId: '1',
    );
    await repo.save(
      targetId.storageKey,
      progress,
      language: LearningLanguage.english,
    );
    await repo.reset(language: LearningLanguage.english);
    final results = await repo.loadAll(
      [
        const ExerciseId(moduleId: 'test', familyId: 'digits', variantId: '0')
            .storageKey,
        targetId.storageKey,
      ],
      language: LearningLanguage.english,
    );
    final stored = results[targetId.storageKey]!;

    expect(stored.learned, false);
    expect(stored.totalAttempts, 0);
    expect(stored.totalCorrect, 0);
    expect(stored.clusters, isEmpty);
    expect(stored.firstAttemptAt, 0);
  });

  test('reset clears only selected language', () async {
    final repo = ProgressRepository(box);
    const progress = CardProgress(
      learned: true,
      clusters: <CardCluster>[
        CardCluster(
          lastAnswerAt: 3000,
          correctCount: 2,
          wrongCount: 0,
          skippedCount: 0,
        ),
      ],
      learnedAt: 3000,
      firstAttemptAt: 3000,
    );

    const targetId = ExerciseId(
      moduleId: 'test',
      familyId: 'digits',
      variantId: '1',
    );
    await repo.save(
      targetId.storageKey,
      progress,
      language: LearningLanguage.english,
    );
    await repo.save(
      targetId.storageKey,
      progress,
      language: LearningLanguage.spanish,
    );

    await repo.reset(language: LearningLanguage.english);

    final englishResults = await repo.loadAll(
      [targetId.storageKey],
      language: LearningLanguage.english,
    );
    final spanishResults = await repo.loadAll(
      [targetId.storageKey],
      language: LearningLanguage.spanish,
    );

    expect(englishResults[targetId.storageKey]!.totalAttempts, 0);
    expect(spanishResults[targetId.storageKey]!.totalAttempts, 2);
  });
}
