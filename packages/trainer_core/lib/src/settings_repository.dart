import 'package:hive/hive.dart';

import 'app_config.dart';
import 'trainer_repositories.dart';
import 'training/domain/learning_language.dart';

const String baseLanguageKey = 'baseLanguage';
const String learningLanguageKey = 'learningLanguage';
const String premiumPronunciationKey = 'premiumPronunciationEnabled';
const String autoSimulationEnabledKey = 'autoSimulationEnabled';
const String autoSimulationContinueCountKey = 'autoSimulationContinueCount';
const String celebrationCounterKey = 'celebrationCounter';
const String dailySessionStatsKeyPrefix = 'dailySessionStats';
const String studyStreakKeyPrefix = 'studyStreak';
const String debugForcedModeKey = 'debugForcedMode';
const String debugForcedFamilyKey = 'debugForcedFamilyKey';
const String ttsVoiceIdPrefix = 'ttsVoiceId';

const bool premiumPronunciationDefault = false;
const bool autoSimulationEnabledDefault = false;
const int autoSimulationContinueCountMin = 0;
const int autoSimulationContinueCountMax = 500;
const int autoSimulationContinueCountDefault = 0;

class SettingsRepository implements SettingsRepositoryBase {
  SettingsRepository(
    this.settingsBox, {
    this.defaultBaseLanguage = LearningLanguage.english,
    this.defaultLearningLanguage = LearningLanguage.english,
  });

  factory SettingsRepository.forApp(Box<String> settingsBox, AppConfig config) {
    return SettingsRepository(
      settingsBox,
      defaultBaseLanguage: config.defaultBaseLanguage,
      defaultLearningLanguage: config.defaultLearningLanguage,
    );
  }

  final Box<String> settingsBox;
  final LearningLanguage defaultBaseLanguage;
  final LearningLanguage defaultLearningLanguage;

  @override
  LearningLanguage readBaseLanguage() {
    return _readLanguage(baseLanguageKey, defaultBaseLanguage);
  }

  @override
  Future<void> setBaseLanguage(LearningLanguage language) async {
    await settingsBox.put(baseLanguageKey, language.code);
  }

  @override
  LearningLanguage readLearningLanguage() {
    return _readLanguage(learningLanguageKey, defaultLearningLanguage);
  }

  @override
  Future<void> setLearningLanguage(LearningLanguage language) async {
    await settingsBox.put(learningLanguageKey, language.code);
  }

  @override
  bool readPremiumPronunciationEnabled() {
    return _readBool(
      premiumPronunciationKey,
      defaultValue: premiumPronunciationDefault,
    );
  }

  @override
  Future<void> setPremiumPronunciationEnabled(bool enabled) async {
    await settingsBox.put(premiumPronunciationKey, enabled.toString());
  }

  @override
  bool readAutoSimulationEnabled() {
    return _readBool(
      autoSimulationEnabledKey,
      defaultValue: autoSimulationEnabledDefault,
    );
  }

  @override
  Future<void> setAutoSimulationEnabled(bool enabled) async {
    await settingsBox.put(autoSimulationEnabledKey, enabled.toString());
  }

  @override
  int readAutoSimulationContinueCount() {
    final raw = settingsBox.get(autoSimulationContinueCountKey);
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null) {
      return autoSimulationContinueCountDefault;
    }
    return _normalizeAutoSimulationContinueCount(parsed);
  }

  @override
  Future<void> setAutoSimulationContinueCount(int count) async {
    await settingsBox.put(
      autoSimulationContinueCountKey,
      _normalizeAutoSimulationContinueCount(count).toString(),
    );
  }

  @override
  int readCelebrationCounter() {
    final raw = settingsBox.get(celebrationCounterKey);
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  @override
  Future<void> setCelebrationCounter(int counter) async {
    await settingsBox.put(
      celebrationCounterKey,
      (counter < 0 ? 0 : counter).toString(),
    );
  }

  @override
  String? readTtsVoiceId(LearningLanguage language) {
    final raw = settingsBox.get(_ttsVoiceKey(language));
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
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
  String? readDebugForcedMode() {
    return _readOptionalString(debugForcedModeKey);
  }

  @override
  Future<void> setDebugForcedMode(String? mode) async {
    await _writeOptionalString(debugForcedModeKey, mode);
  }

  @override
  String? readDebugForcedFamilyKey() {
    return _readOptionalString(debugForcedFamilyKey);
  }

  @override
  Future<void> setDebugForcedFamilyKey(String? familyKey) async {
    await _writeOptionalString(debugForcedFamilyKey, familyKey);
  }

  @override
  DailySessionStats readDailySessionStats({DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final language = readLearningLanguage();
    final raw = settingsBox.get(_dailySessionStatsKey(language));
    if (raw == null || raw.trim().isEmpty) {
      return DailySessionStats.emptyFor(resolvedNow);
    }
    final parts = raw.split('|');
    if (parts.length != 4) {
      return DailySessionStats.emptyFor(resolvedNow);
    }
    final parsed = DailySessionStats(
      dayKey: parts[0].trim(),
      sessionsCompleted: int.tryParse(parts[1]) ?? 0,
      cardsCompleted: int.tryParse(parts[2]) ?? 0,
      durationSeconds: int.tryParse(parts[3]) ?? 0,
    );
    return parsed.normalizedFor(resolvedNow);
  }

  @override
  Future<void> setDailySessionStats(DailySessionStats stats) async {
    final language = readLearningLanguage();
    await settingsBox.put(
      _dailySessionStatsKey(language),
      '${stats.dayKey}|${stats.sessionsCompleted < 0 ? 0 : stats.sessionsCompleted}|'
      '${stats.cardsCompleted < 0 ? 0 : stats.cardsCompleted}|'
      '${stats.durationSeconds < 0 ? 0 : stats.durationSeconds}',
    );
  }

  @override
  StudyStreak readStudyStreak() {
    final language = readLearningLanguage();
    return StudyStreak.fromStorage(settingsBox.get(_studyStreakKey(language)));
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
  }

  bool _readBool(String key, {required bool defaultValue}) {
    final raw = settingsBox.get(key);
    if (raw == 'true') {
      return true;
    }
    if (raw == 'false') {
      return false;
    }
    return defaultValue;
  }

  LearningLanguage _readLanguage(String key, LearningLanguage defaultLanguage) {
    final raw = settingsBox.get(key);
    if (raw == null) {
      return defaultLanguage;
    }
    for (final language in LearningLanguage.values) {
      if (language.code == raw) {
        return language;
      }
    }
    return defaultLanguage;
  }

  String? _readOptionalString(String key) {
    final raw = settingsBox.get(key);
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _writeOptionalString(String key, String? value) async {
    if (value == null || value.trim().isEmpty) {
      await settingsBox.delete(key);
      return;
    }
    await settingsBox.put(key, value.trim());
  }

  int _normalizeAutoSimulationContinueCount(int count) {
    return count
        .clamp(autoSimulationContinueCountMin, autoSimulationContinueCountMax)
        .toInt();
  }

  String _ttsVoiceKey(LearningLanguage language) =>
      '$ttsVoiceIdPrefix.${language.code}';
  String _dailySessionStatsKey(LearningLanguage language) =>
      '$dailySessionStatsKeyPrefix.${language.code}';
  String _studyStreakKey(LearningLanguage language) =>
      '$studyStreakKeyPrefix.${language.code}';
}
