import '../domain/learning_language.dart';
import 'de/pack.dart';
import 'en/pack.dart';
import 'es/pack.dart';
import 'fr/pack.dart';
import 'he/pack.dart';
import 'language_pack.dart';

class LanguageRegistry {
  static final Map<LearningLanguage, LanguagePack> _packs = {
    LearningLanguage.english: buildEnglishPack(),
    LearningLanguage.spanish: buildSpanishPack(),
    LearningLanguage.french: buildFrenchPack(),
    LearningLanguage.german: buildGermanPack(),
    LearningLanguage.hebrew: buildHebrewPack(),
  };

  static LanguagePack of(LearningLanguage language) {
    final pack = _packs[language];
    if (pack == null) {
      throw StateError('Language pack not registered for $language');
    }
    return pack;
  }

  static List<LanguagePack> get supportedPacks => _packs.values.toList();
}
