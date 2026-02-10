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

  NumberWordsConverter numberWordsConverter([LearningLanguage? language]) {
    final selected = language ?? currentLanguage;
    return LanguageRegistry.of(selected).numberWordsConverter;
  }

  TimeWordsConverter timeWordsConverter([LearningLanguage? language]) {
    final selected = language ?? currentLanguage;
    return LanguageRegistry.of(selected).timeWordsConverter;
  }

  String timeToWords(TimeValue value, {LearningLanguage? language}) {
    return timeWordsConverter(language)(value);
  }

  PhraseTemplate? pickTemplate(int value, {LearningLanguage? language}) {
    final selected = language ?? currentLanguage;
    final available = LanguageRegistry.of(
      selected,
    ).phraseTemplates.where((template) => template.supports(value)).toList();
    if (available.isEmpty) return null;
    return available[_random.nextInt(available.length)];
  }

  bool hasTemplate(int value, {LearningLanguage? language}) {
    final selected = language ?? currentLanguage;
    return LanguageRegistry.of(
      selected,
    ).phraseTemplates.any((template) => template.supports(value));
  }
}
