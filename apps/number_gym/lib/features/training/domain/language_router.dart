import 'dart:math';

import '../languages/language_pack.dart';
import '../languages/phrase_template.dart';
import '../languages/registry.dart';
import 'learning_language.dart';
import 'repositories.dart';
import 'time_value.dart';

class LanguageRouter {
  LanguageRouter({
    required SettingsRepositoryBase settingsRepository,
    Random? random,
  }) : _settingsRepository = settingsRepository,
       _random = random ?? Random();

  final SettingsRepositoryBase _settingsRepository;
  final Random _random;

  LearningLanguage get currentLanguage =>
      _settingsRepository.readLearningLanguage();

  NumberWordsConverter numberWordsConverter(LearningLanguage language) {
    return LanguageRegistry.of(language).numberWordsConverter;
  }

  TimeWordsConverter timeWordsConverter(LearningLanguage language) {
    return LanguageRegistry.of(language).timeWordsConverter;
  }

  String timeToWords(TimeValue value, {required LearningLanguage language}) {
    return timeWordsConverter(language)(value);
  }

  PhraseTemplate? pickTemplate(
    int value, {
    required LearningLanguage language,
  }) {
    final available = LanguageRegistry.of(
      language,
    ).phraseTemplates.where((template) => template.supports(value)).toList();
    if (available.isEmpty) return null;
    return available[_random.nextInt(available.length)];
  }

  bool hasTemplate(int value, {required LearningLanguage language}) {
    return LanguageRegistry.of(
      language,
    ).phraseTemplates.any((template) => template.supports(value));
  }
}
