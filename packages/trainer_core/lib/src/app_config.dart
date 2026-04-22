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
}
