import 'package:hive/hive.dart';

import '../domain/learning_language.dart';
import '../domain/repositories.dart';
import '../domain/training_item.dart';
import '../domain/training_task.dart';

const String learningLanguageKey = 'learningLanguage';
const String answerDurationSecondsKey = 'answerDurationSeconds';
const String hintStreakCountKey = 'hintStreakCount';
const String premiumPronunciationKey = 'premiumPronunciationEnabled';
const String debugForcedTaskKindKey = 'debugForcedTaskKind';
const String debugForcedItemTypeKey = 'debugForcedItemType';
const String ttsVoiceIdPrefix = 'ttsVoiceId';

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

  @override
  String? readTtsVoiceId(LearningLanguage language) {
    final rawValue = settingsBox.get(_ttsVoiceKey(language));
    if (rawValue == null) return null;
    final trimmed = rawValue.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> setTtsVoiceId(LearningLanguage language, String? voiceId) async {
    final key = _ttsVoiceKey(language);
    if (voiceId == null || voiceId.trim().isEmpty) {
      await settingsBox.delete(key);
      return;
    }
    await settingsBox.put(key, voiceId.trim());
  }

  @override
  TrainingTaskKind? readDebugForcedTaskKind() {
    final rawValue = settingsBox.get(debugForcedTaskKindKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    for (final kind in TrainingTaskKind.values) {
      if (kind.name == rawValue) {
        return kind;
      }
    }
    return null;
  }

  @override
  Future<void> setDebugForcedTaskKind(TrainingTaskKind? kind) async {
    if (kind == null) {
      await settingsBox.delete(debugForcedTaskKindKey);
      return;
    }
    await settingsBox.put(debugForcedTaskKindKey, kind.name);
  }

  @override
  TrainingItemType? readDebugForcedItemType() {
    final rawValue = settingsBox.get(debugForcedItemTypeKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    for (final type in TrainingItemType.values) {
      if (type.name == rawValue) {
        return type;
      }
    }
    return null;
  }

  @override
  Future<void> setDebugForcedItemType(TrainingItemType? type) async {
    if (type == null) {
      await settingsBox.delete(debugForcedItemTypeKey);
      return;
    }
    await settingsBox.put(debugForcedItemTypeKey, type.name);
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

  String _ttsVoiceKey(LearningLanguage language) {
    return '$ttsVoiceIdPrefix.${language.code}';
  }
}
