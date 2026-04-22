import 'dart:math';

import 'base_language_profile.dart';
import 'exercise_models.dart';
import 'progress_manager.dart';
import 'task_availability.dart';
import 'training/domain/learning_language.dart';

sealed class TaskScheduleResult {
  const TaskScheduleResult();
}

final class TaskScheduleReady extends TaskScheduleResult {
  const TaskScheduleReady({required this.card, required this.mode});

  final ExerciseCard card;
  final ExerciseMode mode;
}

final class TaskSchedulePaused extends TaskScheduleResult {
  const TaskSchedulePaused(this.errorMessage);

  final String errorMessage;
}

final class TaskScheduleFinished extends TaskScheduleResult {
  const TaskScheduleFinished();
}

class TaskScheduler {
  TaskScheduler({
    required TaskAvailabilityRegistry availabilityRegistry,
    required Future<bool> Function() internetChecker,
    Random? random,
  }) : _availabilityRegistry = availabilityRegistry,
       _internetChecker = internetChecker,
       _random = random ?? Random();

  static const int _speakWeight = 70;
  static const int _chooseFromPromptWeight = 15;
  static const int _chooseFromAnswerWeight = 15;
  static const int _listenAndChooseWeight = 15;
  static const int _reviewWeight = 5;

  final TaskAvailabilityRegistry _availabilityRegistry;
  final Future<bool> Function() _internetChecker;
  final Random _random;

  bool _hasInternet = true;
  DateTime? _lastInternetCheck;

  Future<void> warmUpAvailability({
    required LearningLanguage language,
    required BaseLanguageProfile profile,
    required bool premiumPronunciationEnabled,
  }) async {
    await _refreshInternet(force: true);
    await _availabilityRegistry.check(
      ExerciseMode.listenAndChoose,
      _availabilityContext(
        language: language,
        profile: profile,
        premiumPronunciationEnabled: premiumPronunciationEnabled,
      ),
      force: true,
    );
  }

  Future<TaskScheduleResult> scheduleNext({
    required ProgressManager progressManager,
    required LearningLanguage language,
    required BaseLanguageProfile profile,
    required bool premiumPronunciationEnabled,
    ExerciseMode? forcedMode,
    String? forcedFamilyKey,
  }) async {
    if (!progressManager.hasRemainingCards) {
      return const TaskScheduleFinished();
    }

    final context = _availabilityContext(
      language: language,
      profile: profile,
      premiumPronunciationEnabled: premiumPronunciationEnabled,
    );
    final reviewAvailability = await _availabilityRegistry.check(
      ExerciseMode.reviewPronunciation,
      context,
      force: forcedMode == ExerciseMode.reviewPronunciation,
    );
    final listeningAvailability = await _availabilityRegistry.check(
      ExerciseMode.listenAndChoose,
      context,
      force: forcedMode == ExerciseMode.listenAndChoose,
    );
    final speechAvailability = await _availabilityRegistry.check(
      ExerciseMode.speak,
      context,
      force: forcedMode == ExerciseMode.speak,
    );

    final picked = progressManager.pickNextCard(
      isEligible: (card) {
        if (forcedFamilyKey != null &&
            card.family.storageKey != forcedFamilyKey) {
          return false;
        }
        if (forcedMode != null &&
            !card.family.supportedModes.contains(forcedMode)) {
          return false;
        }
        return true;
      },
    );
    if (picked == null) {
      return forcedMode != null || forcedFamilyKey != null
          ? const TaskSchedulePaused('No cards available for selected filters.')
          : const TaskScheduleFinished();
    }

    final allowedModes = <ExerciseMode>[
      for (final mode in picked.family.supportedModes)
        if (_isModeAvailable(
          mode,
          speechAvailability: speechAvailability,
          listeningAvailability: listeningAvailability,
          reviewAvailability: reviewAvailability,
        ))
          mode,
    ];

    if (forcedMode != null) {
      if (!allowedModes.contains(forcedMode)) {
        return TaskSchedulePaused(
          _availabilityMessage(
            forcedMode,
            speechAvailability: speechAvailability,
            listeningAvailability: listeningAvailability,
            reviewAvailability: reviewAvailability,
          ),
        );
      }
      return TaskScheduleReady(card: picked, mode: forcedMode);
    }

    if (allowedModes.isEmpty) {
      return TaskSchedulePaused(
        'No available exercise modes for the selected card.',
      );
    }

    return TaskScheduleReady(
      card: picked,
      mode: _pickMode(allowedModes),
    );
  }

  TaskAvailabilityContext _availabilityContext({
    required LearningLanguage language,
    required BaseLanguageProfile profile,
    required bool premiumPronunciationEnabled,
  }) {
    return TaskAvailabilityContext(
      language: language,
      locale: profile.locale,
      premiumPronunciationEnabled: premiumPronunciationEnabled,
      internetCheck: ({bool force = false}) async {
        await _refreshInternet(force: force);
        return _hasInternet;
      },
    );
  }

  bool _isModeAvailable(
    ExerciseMode mode, {
    required TaskAvailability speechAvailability,
    required TaskAvailability listeningAvailability,
    required TaskAvailability reviewAvailability,
  }) {
    switch (mode) {
      case ExerciseMode.speak:
        return speechAvailability.isAvailable;
      case ExerciseMode.listenAndChoose:
        return listeningAvailability.isAvailable;
      case ExerciseMode.reviewPronunciation:
        return reviewAvailability.isAvailable;
      case ExerciseMode.chooseFromPrompt:
      case ExerciseMode.chooseFromAnswer:
        return true;
    }
  }

  String _availabilityMessage(
    ExerciseMode mode, {
    required TaskAvailability speechAvailability,
    required TaskAvailability listeningAvailability,
    required TaskAvailability reviewAvailability,
  }) {
    switch (mode) {
      case ExerciseMode.speak:
        return speechAvailability.message ??
            'Speech recognition is not available on this device.';
      case ExerciseMode.listenAndChoose:
        return listeningAvailability.message ??
            'Text-to-speech is not available for the selected language.';
      case ExerciseMode.reviewPronunciation:
        return reviewAvailability.message ??
            'Pronunciation review is not available.';
      case ExerciseMode.chooseFromPrompt:
      case ExerciseMode.chooseFromAnswer:
        return 'Selected mode is not available.';
    }
  }

  ExerciseMode _pickMode(List<ExerciseMode> modes) {
    final weighted = <MapEntry<ExerciseMode, int>>[
      if (modes.contains(ExerciseMode.speak))
        const MapEntry(ExerciseMode.speak, _speakWeight),
      if (modes.contains(ExerciseMode.chooseFromPrompt))
        const MapEntry(
          ExerciseMode.chooseFromPrompt,
          _chooseFromPromptWeight,
        ),
      if (modes.contains(ExerciseMode.chooseFromAnswer))
        const MapEntry(
          ExerciseMode.chooseFromAnswer,
          _chooseFromAnswerWeight,
        ),
      if (modes.contains(ExerciseMode.listenAndChoose))
        const MapEntry(
          ExerciseMode.listenAndChoose,
          _listenAndChooseWeight,
        ),
      if (modes.contains(ExerciseMode.reviewPronunciation))
        const MapEntry(
          ExerciseMode.reviewPronunciation,
          _reviewWeight,
        ),
    ];
    final total = weighted.fold(0, (sum, entry) => sum + entry.value);
    final roll = _random.nextInt(total);
    var cursor = 0;
    for (final entry in weighted) {
      cursor += entry.value;
      if (roll < cursor) {
        return entry.key;
      }
    }
    return weighted.last.key;
  }

  Future<void> _refreshInternet({required bool force}) async {
    if (!force && _lastInternetCheck != null) {
      final elapsed = DateTime.now().difference(_lastInternetCheck!);
      if (elapsed < const Duration(seconds: 10)) {
        return;
      }
    }
    _lastInternetCheck = DateTime.now();
    _hasInternet = await _internetChecker();
  }
}
