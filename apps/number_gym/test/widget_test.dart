import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:number_gym/app.dart';
import 'package:number_gym/home_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home shell renders branding and package-driven actions', (
    WidgetTester tester,
  ) async {
    final boxes = _openBoxes();
    try {
      await tester.pumpWidget(_buildTestShell(boxes));
      await _pumpFrames(tester);

      expect(find.text('Number Gym'), findsOneWidget);
      expect(find.text('Start training'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Settings'), 300);
      await _pumpFrames(tester);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Supported languages'), findsOneWidget);
      expect(find.text('Version 1.0.0 (7)'), findsOneWidget);
    } finally {
      await _disposeTestBoxes(tester, boxes);
    }
  });

  testWidgets('home shell opens statistics screen', (
    WidgetTester tester,
  ) async {
    final boxes = _openBoxes();
    try {
      await tester.pumpWidget(_buildTestShell(boxes));
      await _pumpFrames(tester);

      await tester.scrollUntilVisible(find.text('Statistics'), 300);
      await _pumpFrames(tester);
      await tester.tap(find.text('Statistics'));
      await _pumpFrames(tester);

      expect(find.textContaining('Total cards:'), findsOneWidget);
    } finally {
      await _disposeTestBoxes(tester, boxes);
    }
  });

  testWidgets('home shell opens about screen', (WidgetTester tester) async {
    final boxes = _openBoxes();
    try {
      await tester.pumpWidget(_buildTestShell(boxes));
      await _pumpFrames(tester);

      await tester.scrollUntilVisible(find.text('About'), 300);
      await _pumpFrames(tester);
      await tester.tap(find.text('About'));
      await _pumpFrames(tester);

      expect(find.text('NumberGym'), findsOneWidget);
      expect(find.text('Repository'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
    } finally {
      await _disposeTestBoxes(tester, boxes);
    }
  });
}

_TestBoxes _openBoxes() {
  return _TestBoxes(
    settingsBox: _FakeStringBox(),
    progressBox: _FakeCardProgressBox(),
  );
}

Widget _buildTestShell(_TestBoxes boxes) {
  return MaterialApp(
    home: NumberGymHomeScreen(
      config: numberGymConfig,
      appDefinition: numberGymDefinition,
      settingsBox: boxes.settingsBox,
      progressBox: boxes.progressBox,
      statsLoader: _buildStatsLoader(boxes.settingsBox),
      packageInfoLoader: _loadPackageInfo,
    ),
  );
}

Future<void> _disposeTestBoxes(WidgetTester tester, _TestBoxes boxes) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await boxes.settingsBox.close();
  await boxes.progressBox.close();
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 250));
}

class _TestBoxes {
  const _TestBoxes({required this.settingsBox, required this.progressBox});

  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;
}

Future<PackageInfo> _loadPackageInfo() async {
  return PackageInfo(
    appName: 'Number Gym',
    packageName: 'com.dimonsmart.numbergym',
    version: '1.0.0',
    buildNumber: '7',
  );
}

TrainingStatsLoader _buildStatsLoader(Box<String> settingsBox) {
  return TrainingStatsLoader(
    progressRepository: _FakeProgressRepository(),
    settingsRepository: SettingsRepository(settingsBox),
    catalog: ExerciseCatalog(modules: <TrainingModule>[_TestModule()]),
  );
}

class _TestModule implements TrainingModule {
  static final ExerciseFamily _family = ExerciseFamily(
    moduleId: 'test_module',
    id: 'test_family',
    label: 'Test family',
    shortLabel: 'Test',
    difficultyTier: ExerciseDifficultyTier.easy,
    defaultDuration: const Duration(seconds: 10),
    supportedModes: const <ExerciseMode>[ExerciseMode.speak],
  );

  static final ExerciseCard _card = ExerciseCard(
    id: const ExerciseId(
      moduleId: 'test_module',
      familyId: 'test_family',
      variantId: 'sample',
    ),
    family: _family,
    language: LearningLanguage.english,
    displayText: '1',
    promptText: '1',
    acceptedAnswers: const <String>['one'],
    celebrationText: '1 -> one',
  );

  @override
  String get moduleId => 'test_module';

  @override
  String get displayName => 'Test module';

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    if (!supportsLanguage(language)) {
      return const <ExerciseCard>[];
    }
    return <ExerciseCard>[_card];
  }

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) {
    if (!supportsLanguage(language)) {
      return const <ExerciseFamily>[];
    }
    return <ExerciseFamily>[_family];
  }

  @override
  bool supportsLanguage(LearningLanguage language) {
    return language == LearningLanguage.english;
  }
}

class _FakeProgressRepository implements ProgressRepositoryBase {
  @override
  Future<Map<String, CardProgress>> loadAll(
    List<String> storageKeys, {
    required LearningLanguage language,
  }) async {
    return <String, CardProgress>{
      for (final storageKey in storageKeys) storageKey: CardProgress.empty,
    };
  }

  @override
  Future<void> reset({required LearningLanguage language}) async {}

  @override
  Future<void> save(
    String storageKey,
    CardProgress progress, {
    required LearningLanguage language,
  }) async {}
}

class _FakeStringBox extends Fake implements Box<String> {
  final Map<dynamic, String> _values = <dynamic, String>{};

  @override
  String? get(dynamic key, {String? defaultValue}) {
    return _values[key] ?? defaultValue;
  }

  @override
  Future<void> close() async {}
}

class _FakeCardProgressBox extends Fake implements Box<CardProgress> {
  @override
  Future<void> close() async {}
}
