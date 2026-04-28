import 'app_config.dart';
import 'base_language_profile.dart';
import 'exercise_models.dart';
import 'matcher/matcher_tokenizer.dart';
import 'training/domain/learning_language.dart';

class TrainingAppDefinition {
  TrainingAppDefinition({
    required this.config,
    required List<LearningLanguage> supportedLanguages,
    required this.profileOf,
    required this.tokenizerOf,
    required this.catalog,
    this.statisticsDisplay = const StatisticsDisplayConfig(),
  }) : supportedLanguages = List<LearningLanguage>.unmodifiable(
         supportedLanguages,
       );

  final AppConfig config;
  final List<LearningLanguage> supportedLanguages;
  final BaseLanguageProfile Function(LearningLanguage language) profileOf;
  final MatcherTokenizer Function(LearningLanguage language) tokenizerOf;
  final ExerciseCatalog catalog;
  final StatisticsDisplayConfig statisticsDisplay;
}

enum StatisticsConceptDisplayMode { list, compactGrid }

class StatisticsDisplayConfig {
  const StatisticsDisplayConfig({
    this.conceptDisplayMode = StatisticsConceptDisplayMode.list,
    this.compactGridMaxColumns = 5,
    this.defaultCardGrid = const StatisticsCardGridConfig(),
    this.cardGridByFamilyKey = const <String, StatisticsCardGridConfig>{},
  });

  final StatisticsConceptDisplayMode conceptDisplayMode;
  final int compactGridMaxColumns;
  final StatisticsCardGridConfig defaultCardGrid;
  final Map<String, StatisticsCardGridConfig> cardGridByFamilyKey;

  StatisticsCardGridConfig cardGridForFamily(ExerciseFamily family) {
    return cardGridByFamilyKey[family.storageKey] ?? defaultCardGrid;
  }
}

class StatisticsCardGridConfig {
  const StatisticsCardGridConfig({
    this.minTileWidth = 44,
    this.maxColumns = 10,
  });

  final double minTileWidth;
  final int maxColumns;
}
