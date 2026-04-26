import 'training/domain/learning_language.dart';

enum LanguageSettingsMode { learningLanguageOnly, baseAndLearningLanguage }

class AppConfig {
  const AppConfig({
    required this.appId,
    required this.title,
    required this.homeTitle,
    required this.repositoryUrl,
    required this.privacyPolicyUrl,
    required this.aboutTitle,
    required this.aboutBody,
    required this.settingsBoxName,
    required this.progressBoxName,
    required this.heroAssetPath,
    required this.mascotAssetPath,
    this.languageSettingsMode = LanguageSettingsMode.learningLanguageOnly,
    this.defaultBaseLanguage = LearningLanguage.english,
    this.defaultLearningLanguage = LearningLanguage.english,
  });

  final String appId;
  final String title;
  final String homeTitle;
  final String repositoryUrl;
  final String privacyPolicyUrl;
  final String aboutTitle;
  final String aboutBody;
  final String settingsBoxName;
  final String progressBoxName;
  final String heroAssetPath;
  final String mascotAssetPath;
  final LanguageSettingsMode languageSettingsMode;
  final LearningLanguage defaultBaseLanguage;
  final LearningLanguage defaultLearningLanguage;
}
