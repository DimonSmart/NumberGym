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
  }) : supportedLanguages = List<LearningLanguage>.unmodifiable(
         supportedLanguages,
       );

  final AppConfig config;
  final List<LearningLanguage> supportedLanguages;
  final BaseLanguageProfile Function(LearningLanguage language) profileOf;
  final MatcherTokenizer Function(LearningLanguage language) tokenizerOf;
  final ExerciseCatalog catalog;
}
