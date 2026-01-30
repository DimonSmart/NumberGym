import 'dart:math';

import '../languages/language_pack.dart';
import '../languages/phrase_template.dart';
import '../languages/registry.dart';
import 'learning_language.dart';
import 'repositories.dart';

class LanguageRouter {
  LanguageRouter({
    required SettingsRepositoryBase settingsRepository,
    Random? random,
  })  : _settingsRepository = settingsRepository,
        _random = random ?? Random();

  final SettingsRepositoryBase _settingsRepository;
  final Random _random;

  LearningLanguage get currentLanguage =>
      _settingsRepository.readLearningLanguage();

  NumberWordsConverter numberWordsConverter([LearningLanguage? language]) {
    final selected = language ?? currentLanguage;
    return LanguageRegistry.of(selected).numberWordsConverter;
  }

  String numberToWords(int value, {LearningLanguage? language}) {
    return numberWordsConverter(language)(value);
  }

  List<String> numberAnswers(int value, {LearningLanguage? language}) {
    final toWords = numberWordsConverter(language);
    return <String>[
      toWords(value),
      value.toString(),
    ];
  }

  List<PhraseTemplate> templates([LearningLanguage? language]) {
    final selected = language ?? currentLanguage;
    return LanguageRegistry.of(selected).phraseTemplates;
  }

  PhraseTemplate? pickTemplate(int value, {LearningLanguage? language}) {
    final selected = language ?? currentLanguage;
    final available = LanguageRegistry.of(selected)
        .phraseTemplates
        .where((template) => template.supports(value))
        .toList();
    if (available.isEmpty) return null;
    return available[_random.nextInt(available.length)];
  }

  bool hasTemplate(int value, {LearningLanguage? language}) {
    final selected = language ?? currentLanguage;
    return LanguageRegistry.of(selected)
        .phraseTemplates
        .any((template) => template.supports(value));
  }
}
