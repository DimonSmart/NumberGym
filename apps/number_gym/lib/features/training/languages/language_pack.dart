import 'package:flutter/widgets.dart';

import '../domain/learning_language.dart';
import '../domain/time_value.dart';
import 'number_lexicon.dart';
import 'phrase_template.dart';
import 'time_lexicon.dart';

typedef NumberWordsConverter = String Function(int);
typedef TimeWordsConverter = String Function(TimeValue);
typedef TextNormalizer = String Function(String text);

class LanguagePack {
  final LearningLanguage language;
  final String code;
  final String label;
  final String locale;
  final TextDirection textDirection;
  final NumberWordsConverter numberWordsConverter;
  final TimeWordsConverter timeWordsConverter;
  final List<PhraseTemplate> phraseTemplates;
  final NumberLexicon numberLexicon;
  final TimeLexicon timeLexicon;
  final Map<String, String> operatorWords;
  final Set<String> ignoredWords;
  final String ttsPreviewText;
  final String? preferredSpeechLocaleId;
  final TextNormalizer normalizer;

  const LanguagePack({
    required this.language,
    required this.code,
    required this.label,
    required this.locale,
    required this.textDirection,
    required this.numberWordsConverter,
    required this.timeWordsConverter,
    required this.phraseTemplates,
    required this.numberLexicon,
    required this.timeLexicon,
    required this.operatorWords,
    required this.ignoredWords,
    required this.ttsPreviewText,
    required this.preferredSpeechLocaleId,
    required this.normalizer,
  });
}
