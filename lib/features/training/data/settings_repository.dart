import 'package:hive/hive.dart';

import '../domain/learning_language.dart';

const String learningLanguageKey = 'learningLanguage';
const String answerDurationSecondsKey = 'answerDurationSeconds';

const int answerDurationMinSeconds = 5;
const int answerDurationMaxSeconds = 15;
const int answerDurationStepSeconds = 5;
const int answerDurationDefaultSeconds = answerDurationMinSeconds;

class SettingsRepository {
  final Box<String> settingsBox;

  SettingsRepository(this.settingsBox);

  LearningLanguage readLearningLanguage() {
    return LearningLanguageX.fromCode(settingsBox.get(learningLanguageKey));
  }

  Future<void> setLearningLanguage(LearningLanguage language) async {
    await settingsBox.put(learningLanguageKey, language.code);
  }

  int readAnswerDurationSeconds() {
    final rawValue = settingsBox.get(answerDurationSecondsKey);
    final parsed = int.tryParse(rawValue ?? '');
    if (parsed == null) {
      return answerDurationDefaultSeconds;
    }
    return _normalizeAnswerDurationSeconds(parsed);
  }

  Future<void> setAnswerDurationSeconds(int seconds) async {
    final normalized = _normalizeAnswerDurationSeconds(seconds);
    await settingsBox.put(answerDurationSecondsKey, normalized.toString());
  }

  int _normalizeAnswerDurationSeconds(int seconds) {
    final clamped = seconds.clamp(
      answerDurationMinSeconds,
      answerDurationMaxSeconds,
    );
    final stepIndex =
        ((clamped - answerDurationMinSeconds) / answerDurationStepSeconds)
            .round();
    return answerDurationMinSeconds + stepIndex * answerDurationStepSeconds;
  }
}
