import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:number_gym/features/training/data/settings_repository.dart';

void main() {
  late Directory tempDir;
  late Box<String> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_repo_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    box = await Hive.openBox<String>('settings_repo_test');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('settings_repo_test');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('celebration counter defaults to zero', () {
    final repository = SettingsRepository(box);
    expect(repository.readCelebrationCounter(), 0);
  });

  test('celebration counter is persisted as non-negative value', () async {
    final repository = SettingsRepository(box);
    await repository.setCelebrationCounter(-3);
    expect(repository.readCelebrationCounter(), 0);

    await repository.setCelebrationCounter(7);
    expect(repository.readCelebrationCounter(), 7);
  });
}
