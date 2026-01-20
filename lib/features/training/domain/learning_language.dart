enum LearningLanguage { english, spanish }

extension LearningLanguageX on LearningLanguage {
  String get code => this == LearningLanguage.spanish ? 'es' : 'en';

  String get label => this == LearningLanguage.spanish ? 'Spanish' : 'English';

  String get localePrefix => this == LearningLanguage.spanish ? 'es' : 'en';

  static LearningLanguage fromCode(String? code) {
    if (code == 'es') return LearningLanguage.spanish;
    return LearningLanguage.english;
  }
}
