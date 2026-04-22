import 'package:flutter/widgets.dart';

import 'training/domain/learning_language.dart';

typedef TextNormalizer = String Function(String text);

class BaseLanguageProfile {
  const BaseLanguageProfile({
    required this.language,
    required this.code,
    required this.label,
    required this.locale,
    required this.textDirection,
    required this.ttsPreviewText,
    required this.preferredSpeechLocaleId,
    required this.normalizer,
  });

  final LearningLanguage language;
  final String code;
  final String label;
  final String locale;
  final TextDirection textDirection;
  final String ttsPreviewText;
  final String? preferredSpeechLocaleId;
  final TextNormalizer normalizer;
}
