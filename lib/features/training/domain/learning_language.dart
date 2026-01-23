enum LearningLanguage { english, spanish }

extension LearningLanguageX on LearningLanguage {
  String get code {
    switch (this) {
      case LearningLanguage.english:
        return 'en';
      case LearningLanguage.spanish:
        return 'es';
    }
  }

  String get label {
    switch (this) {
      case LearningLanguage.english:
        return 'English';
      case LearningLanguage.spanish:
        return 'Spanish';
    }
  }

  String get locale {
    switch (this) {
      case LearningLanguage.english:
        return 'en-US';
      case LearningLanguage.spanish:
        return 'es-ES';
    }
  }

  static LearningLanguage fromCode(String? code) {
    switch (code) {
      case 'en':
        return LearningLanguage.english;
      case 'es':
        return LearningLanguage.spanish;
      default:
        return LearningLanguage.english;
    }
  }
}
