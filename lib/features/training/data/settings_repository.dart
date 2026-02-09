import 'package:hive/hive.dart';

import '../domain/daily_session_stats.dart';
import '../domain/learning_language.dart';
import '../domain/repositories.dart';
import '../domain/study_streak.dart';
import '../domain/training_item.dart';
import '../domain/training_task.dart';

const String learningLanguageKey = 'learningLanguage';
const String answerDurationSecondsKey = 'answerDurationSeconds';
const String hintStreakCountKey = 'hintStreakCount';
const String premiumPronunciationKey = 'premiumPronunciationEnabled';
const String autoSimulationEnabledKey = 'autoSimulationEnabled';
const String autoSimulationContinueCountKey = 'autoSimulationContinueCount';
const String celebrationCounterKey = 'celebrationCounter';
const String dailySessionStatsKeyPrefix = 'dailySessionStats';
const String studyStreakKeyPrefix = 'studyStreak';
// Keep stored key names for backward compatibility with older builds.
const String dailySessionStatsLegacyKey = 'dailySessionStats';
const String studyStreakLegacyKey = 'studyStreak';
// Keep stored key name for backward compatibility with older builds.
const String debugForcedLearningMethodKey = 'debugForcedTaskKind';
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
const bool autoSimulationEnabledDefault = false;
const int autoSimulationContinueCountMin = 0;
const int autoSimulationContinueCountMax = 500;
const int autoSimulationContinueCountDefault = 0;

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
  bool readAutoSimulationEnabled() {
    final rawValue = settingsBox.get(autoSimulationEnabledKey);
    if (rawValue == null) return autoSimulationEnabledDefault;
    if (rawValue == 'true') return true;
    if (rawValue == 'false') return false;
    return autoSimulationEnabledDefault;
  }

  @override
  Future<void> setAutoSimulationEnabled(bool enabled) async {
    await settingsBox.put(autoSimulationEnabledKey, enabled.toString());
  }

  @override
  int readAutoSimulationContinueCount() {
    final rawValue = settingsBox.get(autoSimulationContinueCountKey);
    final parsed = int.tryParse(rawValue ?? '');
    if (parsed == null) {
      return autoSimulationContinueCountDefault;
    }
    return _normalizeAutoSimulationContinueCount(parsed);
  }

  @override
  Future<void> setAutoSimulationContinueCount(int count) async {
    final normalized = _normalizeAutoSimulationContinueCount(count);
    await settingsBox.put(
      autoSimulationContinueCountKey,
      normalized.toString(),
    );
  }

  @override
  int readCelebrationCounter() {
    final rawValue = settingsBox.get(celebrationCounterKey);
    final parsed = int.tryParse(rawValue ?? '');
    if (parsed == null || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  @override
  Future<void> setCelebrationCounter(int counter) async {
    final normalized = counter < 0 ? 0 : counter;
    await settingsBox.put(celebrationCounterKey, normalized.toString());
  }

  @override
  DailySessionStats readDailySessionStats({DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final language = readLearningLanguage();
    final rawValue = settingsBox.get(_dailySessionStatsKey(language));
    if (rawValue == null || rawValue.trim().isEmpty) {
      return DailySessionStats.emptyFor(resolvedNow);
    }

    final parts = rawValue.split('|');
    if (parts.length != 4) {
      return DailySessionStats.emptyFor(resolvedNow);
    }

    final dayKey = parts[0].trim();
    final sessions = int.tryParse(parts[1]) ?? 0;
    final cards = int.tryParse(parts[2]) ?? 0;
    final seconds = int.tryParse(parts[3]) ?? 0;
    final parsed = DailySessionStats(
      dayKey: dayKey,
      sessionsCompleted: sessions < 0 ? 0 : sessions,
      cardsCompleted: cards < 0 ? 0 : cards,
      durationSeconds: seconds < 0 ? 0 : seconds,
    );
    return parsed.normalizedFor(resolvedNow);
  }

  @override
  Future<void> setDailySessionStats(DailySessionStats stats) async {
    final language = readLearningLanguage();
    final normalized = DailySessionStats(
      dayKey: stats.dayKey,
      sessionsCompleted: stats.sessionsCompleted < 0
          ? 0
          : stats.sessionsCompleted,
      cardsCompleted: stats.cardsCompleted < 0 ? 0 : stats.cardsCompleted,
      durationSeconds: stats.durationSeconds < 0 ? 0 : stats.durationSeconds,
    );
    final serialized =
        '${normalized.dayKey}|${normalized.sessionsCompleted}|${normalized.cardsCompleted}|${normalized.durationSeconds}';
    await settingsBox.put(_dailySessionStatsKey(language), serialized);
  }

  @override
  StudyStreak readStudyStreak() {
    final language = readLearningLanguage();
    final rawValue = settingsBox.get(_studyStreakKey(language));
    return StudyStreak.fromStorage(rawValue);
  }

  @override
  Future<void> setStudyStreak(StudyStreak streak) async {
    final language = readLearningLanguage();
    final serialized = streak.toStorage();
    if (serialized.isEmpty) {
      await settingsBox.delete(_studyStreakKey(language));
      return;
    }
    await settingsBox.put(_studyStreakKey(language), serialized);
  }

  Future<void> resetProgressForLanguage(LearningLanguage language) async {
    await settingsBox.delete(_dailySessionStatsKey(language));
    await settingsBox.delete(_studyStreakKey(language));

    // Remove obsolete non-scoped keys so legacy data doesn't leak into UI.
    await settingsBox.delete(dailySessionStatsLegacyKey);
    await settingsBox.delete(studyStreakLegacyKey);
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
  LearningMethod? readDebugForcedLearningMethod() {
    final rawValue = settingsBox.get(debugForcedLearningMethodKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    final normalized = switch (rawValue) {
      'numberToWord' => 'valueToText',
      'wordToNumber' => 'textToValue',
      'wordToTime' => 'textToValue',
      _ => rawValue,
    };
    for (final method in LearningMethod.values) {
      if (method.name == normalized) {
        return method;
      }
    }
    return null;
  }

  @override
  Future<void> setDebugForcedLearningMethod(LearningMethod? method) async {
    if (method == null) {
      await settingsBox.delete(debugForcedLearningMethodKey);
      return;
    }
    await settingsBox.put(debugForcedLearningMethodKey, method.name);
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

  int _normalizeAutoSimulationContinueCount(int count) {
    return count
        .clamp(autoSimulationContinueCountMin, autoSimulationContinueCountMax)
        .toInt();
  }

  String _ttsVoiceKey(LearningLanguage language) {
    return '$ttsVoiceIdPrefix.${language.code}';
  }

  String _dailySessionStatsKey(LearningLanguage language) {
    return '$dailySessionStatsKeyPrefix.${language.code}';
  }

  String _studyStreakKey(LearningLanguage language) {
    return '$studyStreakKeyPrefix.${language.code}';
  }
}
