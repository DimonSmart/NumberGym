import 'package:hive/hive.dart';

import '../domain/learning_language.dart';
import '../domain/repositories.dart';

const String learningLanguageKey = 'learningLanguage';
const String answerDurationSecondsKey = 'answerDurationSeconds';
const String hintStreakCountKey = 'hintStreakCount';
const String premiumPronunciationKey = 'premiumPronunciationEnabled';

const int answerDurationMinSeconds = 5;
const int answerDurationMaxSeconds = 15;
const int answerDurationStepSeconds = 5;
const int answerDurationDefaultSeconds = answerDurationMinSeconds;

const int hintStreakMinCount = 0;
const int hintStreakMaxCount = 6;
const int hintStreakDefaultCount = 3;
const bool premiumPronunciationDefault = false;

class SettingsRepository implements SettingsRepositoryBase {
  final Box<String> settingsBox;

  SettingsRepository(this.settingsBox);

  @override
  LearningLanguage readLearningLanguage() {
    return LearningLanguageX.fromCode(settingsBox.get(learningLanguageKey));
  }

  @override
  Future<void> setLearningLanguage(LearningLanguage language) async {
    await settingsBox.put(learningLanguageKey, language.code);
  }

  @override
  int readAnswerDurationSeconds() {
    final rawValue = settingsBox.get(answerDurationSecondsKey);
    final parsed = int.tryParse(rawValue ?? '');
    if (parsed == null) {
      return answerDurationDefaultSeconds;
    }
    return _normalizeAnswerDurationSeconds(parsed);
  }

  @override
  Future<void> setAnswerDurationSeconds(int seconds) async {
    final normalized = _normalizeAnswerDurationSeconds(seconds);
    await settingsBox.put(answerDurationSecondsKey, normalized.toString());
  }

  @override
  int readHintStreakCount() {
    final rawValue = settingsBox.get(hintStreakCountKey);
    final parsed = int.tryParse(rawValue ?? '');
    if (parsed == null) {
      return hintStreakDefaultCount;
    }
    return _normalizeHintStreakCount(parsed);
  }

  @override
  Future<void> setHintStreakCount(int count) async {
    final normalized = _normalizeHintStreakCount(count);
    await settingsBox.put(hintStreakCountKey, normalized.toString());
  }

  @override
  bool readPremiumPronunciationEnabled() {
    final rawValue = settingsBox.get(premiumPronunciationKey);
    if (rawValue == null) return premiumPronunciationDefault;
    if (rawValue == 'true') return true;
    if (rawValue == 'false') return false;
    return premiumPronunciationDefault;
  }

  @override
  Future<void> setPremiumPronunciationEnabled(bool enabled) async {
    await settingsBox.put(premiumPronunciationKey, enabled.toString());
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

  int _normalizeHintStreakCount(int count) {
    return count.clamp(hintStreakMinCount, hintStreakMaxCount).toInt();
  }
}
