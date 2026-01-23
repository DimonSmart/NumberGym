import 'dart:math';

import '../data/number_words.dart';
import '../data/phrase_templates.dart';
import 'learning_language.dart';
import 'repositories.dart';

class LanguageRouter {
  LanguageRouter({
    required SettingsRepositoryBase settingsRepository,
    PhraseTemplates? phraseTemplates,
    Random? random,
  })  : _settingsRepository = settingsRepository,
        _phraseTemplates = phraseTemplates ?? PhraseTemplates(random ?? Random());

  final SettingsRepositoryBase _settingsRepository;
  final PhraseTemplates _phraseTemplates;

  LearningLanguage get currentLanguage =>
      _settingsRepository.readLearningLanguage();

  NumberWordsConverter numberWordsConverter([LearningLanguage? language]) {
    final selected = language ?? currentLanguage;
    return numberWordsFor(selected);
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
    return _phraseTemplates.forLanguage(selected);
  }

  PhraseTemplate? pickTemplate(int value, {LearningLanguage? language}) {
    final selected = language ?? currentLanguage;
    return _phraseTemplates.pick(selected, value);
  }

  bool hasTemplate(int value, {LearningLanguage? language}) {
    final selected = language ?? currentLanguage;
    return _phraseTemplates
        .forLanguage(selected)
        .any((template) => template.supports(value));
  }
}
