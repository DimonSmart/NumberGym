import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/data/progress_repository.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/training_item.dart';

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

  test('loadAll returns entries for provided ids', () async {
    final repo = ProgressRepository(box);
    final ids = <TrainingItemId>[
      const TrainingItemId(type: TrainingItemType.digits, number: 0),
      const TrainingItemId(type: TrainingItemType.digits, number: 1),
      const TrainingItemId(type: TrainingItemType.digits, number: 2),
    ];
    final results = await repo.loadAll(
      ids,
      language: LearningLanguage.english,
    );

    expect(results.length, ids.length);
    expect(results.keys, containsAll(ids));
    expect(results[ids[0]]!.totalAttempts, 0);
    expect(results[ids[0]]!.totalCorrect, 0);
  });

  test('save persists progress', () async {
    final repo = ProgressRepository(box);
    const progress = CardProgress(
      learned: true,
      lastAttempts: <bool>[true, true, false],
      totalAttempts: 5,
      totalCorrect: 4,
    );

    const targetId = TrainingItemId(
      type: TrainingItemType.digits,
      number: 2,
    );
    await repo.save(targetId, progress, language: LearningLanguage.english);
    final results = await repo.loadAll(
      <TrainingItemId>[
        const TrainingItemId(type: TrainingItemType.digits, number: 0),
        const TrainingItemId(type: TrainingItemType.digits, number: 1),
        targetId,
      ],
      language: LearningLanguage.english,
    );
    final stored = results[targetId]!;

    expect(stored.learned, true);
    expect(stored.totalAttempts, 5);
    expect(stored.totalCorrect, 4);
    expect(stored.lastAttempts.length, 3);
  });

  test('reset clears progress', () async {
    final repo = ProgressRepository(box);
    const progress = CardProgress(
      learned: false,
      lastAttempts: <bool>[true],
      totalAttempts: 1,
      totalCorrect: 1,
    );

    const targetId = TrainingItemId(
      type: TrainingItemType.digits,
      number: 1,
    );
    await repo.save(targetId, progress, language: LearningLanguage.english);
    await repo.reset(language: LearningLanguage.english);
    final results = await repo.loadAll(
      <TrainingItemId>[
        const TrainingItemId(type: TrainingItemType.digits, number: 0),
        targetId,
      ],
      language: LearningLanguage.english,
    );
    final stored = results[targetId]!;

    expect(stored.learned, false);
    expect(stored.totalAttempts, 0);
    expect(stored.totalCorrect, 0);
    expect(stored.lastAttempts, isEmpty);
  });

  test('reset clears only selected language', () async {
    final repo = ProgressRepository(box);
    const progress = CardProgress(
      learned: true,
      lastAttempts: <bool>[true, true],
      totalAttempts: 2,
      totalCorrect: 2,
    );

    const targetId = TrainingItemId(
      type: TrainingItemType.digits,
      number: 1,
    );
    await repo.save(targetId, progress, language: LearningLanguage.english);
    await repo.save(targetId, progress, language: LearningLanguage.spanish);

    await repo.reset(language: LearningLanguage.english);

    final english = await repo.loadAll(
      <TrainingItemId>[targetId],
      language: LearningLanguage.english,
    );
    final spanish = await repo.loadAll(
      <TrainingItemId>[targetId],
      language: LearningLanguage.spanish,
    );

    expect(english[targetId]!.totalAttempts, 0);
    expect(spanish[targetId]!.totalAttempts, 2);
  });
}
