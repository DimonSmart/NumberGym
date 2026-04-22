enum LearningLanguage { english, spanish, french, german, hebrew }

extension LearningLanguageX on LearningLanguage {
  String get code {
    switch (this) {
      case LearningLanguage.english:
        return 'en';
      case LearningLanguage.spanish:
        return 'es';
      case LearningLanguage.french:
        return 'fr';
      case LearningLanguage.german:
        return 'de';
      case LearningLanguage.hebrew:
        return 'he';
    }
  }

  static LearningLanguage fromCode(String? code) {
    switch (code) {
      case 'en':
        return LearningLanguage.english;
      case 'es':
        return LearningLanguage.spanish;
      case 'fr':
        return LearningLanguage.french;
      case 'de':
        return LearningLanguage.german;
      case 'he':
        return LearningLanguage.hebrew;
      default:
        return LearningLanguage.english;
    }
  }
}
