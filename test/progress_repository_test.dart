import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hello_label/features/training/data/card_progress.dart';
import 'package:hello_label/features/training/data/progress_repository.dart';

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

  test('loadAll returns entries through max id', () async {
    final repo = ProgressRepository(box);
    final results = await repo.loadAll(maxCardId: 2);

    expect(results.length, 3);
    expect(results.keys, containsAll(<int>[0, 1, 2]));
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

    await repo.save(2, progress);
    final results = await repo.loadAll(maxCardId: 2);
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

    await repo.save(1, progress);
    await repo.reset();
    final results = await repo.loadAll(maxCardId: 1);
    final stored = results[1]!;

    expect(stored.learned, false);
    expect(stored.totalAttempts, 0);
    expect(stored.totalCorrect, 0);
    expect(stored.lastAttempts, isEmpty);
  });
}
