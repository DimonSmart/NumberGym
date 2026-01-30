import '../domain/learning_language.dart';
import '../languages/registry.dart';

String numberToEnglish(int value) {
  return LanguageRegistry.of(LearningLanguage.english).numberWordsConverter(
    value,
  );
}

String numberToSpanish(int value) {
  return LanguageRegistry.of(LearningLanguage.spanish).numberWordsConverter(
    value,
  );
}
