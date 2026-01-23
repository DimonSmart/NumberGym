import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:number_gym/features/training/data/card_progress.dart';
import 'package:number_gym/features/training/data/progress_repository.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';

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
    final ids = <int>[0, 1, 2];
    final results = await repo.loadAll(
      ids,
      language: LearningLanguage.english,
    );

    expect(results.length, ids.length);
    expect(results.keys, containsAll(ids));
    expect(results[0]!.totalAttempts, 0);
    expect(results[0]!.totalCorrect, 0);
  });

  test('save persists progress', () async {
    final repo = ProgressRepository(box);
    const progress = CardProgress(
      learned: true,
      lastAttempts: <bool>[true, true, false],
      totalAttempts: 5,
      totalCorrect: 4,
    );

    await repo.save(2, progress, language: LearningLanguage.english);
    final results = await repo.loadAll(
      <int>[0, 1, 2],
      language: LearningLanguage.english,
    );
    final stored = results[2]!;

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

    await repo.save(1, progress, language: LearningLanguage.english);
    await repo.reset(language: LearningLanguage.english);
    final results = await repo.loadAll(
      <int>[0, 1],
      language: LearningLanguage.english,
    );
    final stored = results[1]!;

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

    await repo.save(1, progress, language: LearningLanguage.english);
    await repo.save(1, progress, language: LearningLanguage.spanish);

    await repo.reset(language: LearningLanguage.english);

    final english = await repo.loadAll(
      <int>[1],
      language: LearningLanguage.english,
    );
    final spanish = await repo.loadAll(
      <int>[1],
      language: LearningLanguage.spanish,
    );

    expect(english[1]!.totalAttempts, 0);
    expect(spanish[1]!.totalAttempts, 2);
  });
}
