import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

import 'helpers/training_fakes.dart';

final _localizedFamily = ExerciseFamily(
  moduleId: 'stats_test',
  id: 'present',
  label: 'Present',
  shortLabel: 'Present',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: const Duration(seconds: 15),
  supportedModes: [ExerciseMode.chooseFromPrompt],
  localizedLabels: const <LearningLanguage, String>{
    LearningLanguage.english: 'Present',
    LearningLanguage.spanish: 'Presente',
  },
);

const _concept = ExerciseConcept(
  id: 'concept',
  learningLabel: 'concepto',
  baseLabel: 'concept',
);
const _longSpanishPrompt =
    'Estoy aquí con un libro muy grande en la mesa durante toda la mañana '
    'mientras practico español lentamente.';

void main() {
  testWidgets('shows family title in learning and base languages', (
    tester,
  ) async {
    _mockBackgroundAsset();
    final settingsRepository = FakeSettingsRepository(
      baseLanguage: LearningLanguage.english,
      language: LearningLanguage.spanish,
    );
    final statsLoader = TrainingStatsLoader(
      progressRepository: InMemoryProgressRepository(),
      settingsRepository: settingsRepository,
      catalog: ExerciseCatalog(modules: [_StatsTestModule()]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          appDefinition: _appDefinition,
          statsLoader: statsLoader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Presente / Present'), findsOneWidget);
  });

  testWidgets(
    'shows credited correct progress without learned summary labels',
    (tester) async {
      _mockBackgroundAsset();
      final settingsRepository = FakeSettingsRepository(
        baseLanguage: LearningLanguage.english,
        language: LearningLanguage.spanish,
      );
      final progressRepository = InMemoryProgressRepository();
      await progressRepository.save(
        const ExerciseId(
          moduleId: 'stats_test',
          familyId: 'present',
          variantId: 'concept::I',
        ).storageKey,
        const CardProgress(
          learned: false,
          clusters: <CardCluster>[
            CardCluster(
              lastAnswerAt: 1,
              correctCount: 2,
              wrongCount: 1,
              skippedCount: 0,
            ),
          ],
          learnedAt: 0,
          firstAttemptAt: 1,
          consecutiveCorrect: 0,
        ),
        language: LearningLanguage.spanish,
      );
      final statsLoader = TrainingStatsLoader(
        progressRepository: progressRepository,
        settingsRepository: settingsRepository,
        catalog: ExerciseCatalog(modules: [_StatsTestModule()]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsScreen(
            appDefinition: _appDefinition,
            statsLoader: statsLoader,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Learned concepts: 0/1'), findsNothing);
      expect(find.text('0/1 learned'), findsNothing);
      expect(find.text('2/3 correct'), findsNothing);
      expect(find.text('2/20'), findsWidgets);
      expect(find.text('concepto'), findsNothing);
      expect(find.textContaining('lentamente'), findsNothing);

      await tester.tap(find.text('concept'));
      await tester.pumpAndSettle();

      expect(find.text('concepto'), findsOneWidget);
      expect(find.textContaining('lentamente'), findsOneWidget);
      expect(find.text('I am here.'), findsNothing);
      expect(find.text('2/20'), findsWidgets);
    },
  );
}

void _mockBackgroundAsset() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage(
            <String, List<Object?>>{},
          );
        }
        if (key != 'assets/images/background.png') {
          return null;
        }
        return ByteData.sublistView(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
          ),
        );
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
}

class _StatsTestModule implements TrainingModule {
  @override
  String get moduleId => 'stats_test';

  @override
  String get displayName => 'Stats test';

  @override
  bool supportsLanguage(LearningLanguage language) {
    return language == LearningLanguage.spanish;
  }

  @override
  List<ExerciseFamily> buildFamilies(LearningLanguage language) {
    return <ExerciseFamily>[_localizedFamily];
  }

  @override
  List<ExerciseCard> buildCards(LearningLanguage language) {
    final id = ExerciseId(
      moduleId: moduleId,
      familyId: _localizedFamily.id,
      variantId: 'concept::I',
    );
    return <ExerciseCard>[
      ExerciseCard(
        id: id,
        family: _localizedFamily,
        language: language,
        displayText: 'I am here.',
        promptText: _longSpanishPrompt,
        acceptedAnswers: const <String>[_longSpanishPrompt],
        celebrationText: 'I am here. -> $_longSpanishPrompt',
        concept: _concept,
        chooseFromPrompt: ChoiceExerciseSpec(
          prompt: 'I am here.',
          correctOption: _longSpanishPrompt,
          options: const <String>[
            _longSpanishPrompt,
            'Estás aquí.',
            'Está aquí.',
            'Estamos aquí.',
          ],
        ),
      ),
    ];
  }
}

final _appDefinition = TrainingAppDefinition(
  config: const AppConfig(
    appId: 'stats_test',
    title: 'Stats Test',
    homeTitle: 'Stats Test',
    repositoryUrl: 'https://example.com/repo',
    privacyPolicyUrl: 'https://example.com/privacy',
    aboutTitle: 'About',
    aboutBody: 'About body',
    settingsBoxName: 'stats_test_settings',
    progressBoxName: 'stats_test_progress',
    heroAssetPath: 'assets/images/branding/wordmark.png',
    mascotAssetPath: 'assets/images/app_icon.png',
    languageSettingsMode: LanguageSettingsMode.baseAndLearningLanguage,
    defaultBaseLanguage: LearningLanguage.english,
    defaultLearningLanguage: LearningLanguage.spanish,
  ),
  supportedLanguages: const <LearningLanguage>[
    LearningLanguage.english,
    LearningLanguage.spanish,
  ],
  profileOf: _profileOf,
  tokenizerOf: (language) => GenericMatcherTokenizer(_normalize),
  catalog: ExerciseCatalog(modules: [_StatsTestModule()]),
  statisticsDisplay: const StatisticsDisplayConfig(
    conceptDisplayMode: StatisticsConceptDisplayMode.compactGrid,
  ),
);

BaseLanguageProfile _profileOf(LearningLanguage language) {
  return BaseLanguageProfile(
    language: language,
    code: language.code,
    label: language.name,
    locale: language == LearningLanguage.spanish ? 'es-ES' : 'en-US',
    textDirection: TextDirection.ltr,
    ttsPreviewText: language == LearningLanguage.spanish ? 'hola' : 'hello',
    preferredSpeechLocaleId: null,
    normalizer: _normalize,
  );
}

String _normalize(String text) => text.trim().toLowerCase();
