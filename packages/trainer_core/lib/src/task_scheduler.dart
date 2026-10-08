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
    Random? random,
  }) : _availabilityRegistry = availabilityRegistry,
       _random = random ?? Random();

  static const int _speakWeight = 70;
  static const int _chooseFromPromptWeight = 15;
  static const int _chooseFromAnswerWeight = 15;
  static const int _listenAndChooseWeight = 15;

  final TaskAvailabilityRegistry _availabilityRegistry;
  final Random _random;

  Future<void> warmUpAvailability({
    required LearningLanguage language,
    required BaseLanguageProfile profile,
    required bool requestSpeechPermission,
  }) async {
    final context = _availabilityContext(
      language: language,
      profile: profile,
    );
    if (requestSpeechPermission) {
      await _availabilityRegistry.check(
        ExerciseMode.speak,
        context,
        force: true,
      );
    }
    await _availabilityRegistry.check(
      ExerciseMode.listenAndChoose,
      context,
      force: true,
    );
  }

  Future<TaskScheduleResult> scheduleNext({
    required ProgressManager progressManager,
    required LearningLanguage language,
    required BaseLanguageProfile profile,
    ExerciseMode? forcedMode,
    String? forcedFamilyKey,
  }) async {
    if (!progressManager.hasRemainingCards) {
      return const TaskScheduleFinished();
    }

    final context = _availabilityContext(
      language: language,
      profile: profile,
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
        if (forcedMode == null) {
          return card.family.supportedModes.any(
            (mode) => _isModeAvailable(
              mode,
              speechAvailability: speechAvailability,
              listeningAvailability: listeningAvailability,
            ),
          );
        }
        return true;
      },
    );
    if (picked == null) {
      return forcedMode != null || forcedFamilyKey != null
          ? const TaskSchedulePaused('No cards available for selected filters.')
          : const TaskSchedulePaused(
              'No exercises can run with the available device capabilities.',
            );
    }

    final allowedModes = <ExerciseMode>[
      for (final mode in picked.family.supportedModes)
        if (_isModeAvailable(
          mode,
          speechAvailability: speechAvailability,
          listeningAvailability: listeningAvailability,
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

    return TaskScheduleReady(card: picked, mode: _pickMode(allowedModes));
  }

  TaskAvailabilityContext _availabilityContext({
    required LearningLanguage language,
    required BaseLanguageProfile profile,
  }) {
    return TaskAvailabilityContext(
      language: language,
      locale: profile.locale,
    );
  }

  bool _isModeAvailable(
    ExerciseMode mode, {
    required TaskAvailability speechAvailability,
    required TaskAvailability listeningAvailability,
  }) {
    switch (mode) {
      case ExerciseMode.speak:
        return speechAvailability.isAvailable;
      case ExerciseMode.listenAndChoose:
        return listeningAvailability.isAvailable;
      case ExerciseMode.chooseFromPrompt:
      case ExerciseMode.chooseFromAnswer:
        return true;
    }
  }

  String _availabilityMessage(
    ExerciseMode mode, {
    required TaskAvailability speechAvailability,
    required TaskAvailability listeningAvailability,
  }) {
    switch (mode) {
      case ExerciseMode.speak:
        return speechAvailability.message ??
            'Speech recognition is not available on this device.';
      case ExerciseMode.listenAndChoose:
        return listeningAvailability.message ??
            'Text-to-speech is not available for the selected language.';
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
        const MapEntry(ExerciseMode.chooseFromPrompt, _chooseFromPromptWeight),
      if (modes.contains(ExerciseMode.chooseFromAnswer))
        const MapEntry(ExerciseMode.chooseFromAnswer, _chooseFromAnswerWeight),
      if (modes.contains(ExerciseMode.listenAndChoose))
        const MapEntry(ExerciseMode.listenAndChoose, _listenAndChooseWeight),
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
}
