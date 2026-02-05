import 'dart:math';

import 'language_router.dart';
import 'learning_language.dart';
import 'progress_manager.dart';
import 'session_helpers.dart';
import 'task_availability.dart';
import 'training_services.dart';
import 'training_item.dart';
import 'training_task.dart';

sealed class TaskScheduleResult {
  const TaskScheduleResult();
}

final class TaskScheduleReady extends TaskScheduleResult {
  const TaskScheduleReady({
    required this.card,
    required this.kind,
  });

  final PronunciationTaskData card;
  final TrainingTaskKind kind;
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
    required LanguageRouter languageRouter,
    required TaskAvailabilityRegistry availabilityRegistry,
    required InternetChecker internetChecker,
    Duration internetCache = const Duration(seconds: 10),
    Random? random,
  })  : _languageRouter = languageRouter,
        _availabilityRegistry = availabilityRegistry,
        _internetGate = InternetGate(
          checker: internetChecker,
          cache: internetCache,
        ),
        _random = random ?? Random();

  static const int _numberPronunciationWeight = 70;
  static const int _valueToTextWeight = 15;
  static const int _textToValueWeight = 15;
  static const int _listeningWeight = 15;
  static const int _phrasePronunciationWeight = 5;

  final LanguageRouter _languageRouter;
  final TaskAvailabilityRegistry _availabilityRegistry;
  final InternetGate _internetGate;
  final Random _random;

  Future<void> warmUpAvailability({
    required LearningLanguage language,
    required bool premiumPronunciationEnabled,
  }) async {
    await _internetGate.refresh(force: true);
    final context = _availabilityContext(
      language: language,
      premiumPronunciationEnabled: premiumPronunciationEnabled,
    );
    await _availabilityRegistry.check(
      TrainingTaskKind.listening,
      context,
      force: true,
    );
  }

  Future<TaskScheduleResult> scheduleNext({
    required ProgressManager progressManager,
    required LearningLanguage language,
    required bool premiumPronunciationEnabled,
    TrainingTaskKind? forcedTaskKind,
    TrainingItemType? forcedItemType,
  }) async {
    if (!progressManager.hasRemainingCards) {
      return const TaskScheduleFinished();
    }

    if (forcedTaskKind != null &&
        forcedItemType != null &&
        !forcedTaskKind.supportedItemTypes.contains(forcedItemType)) {
      return const TaskSchedulePaused(
        'Selected task does not support the selected card type.',
      );
    }

    final requirePhrase =
        forcedTaskKind == TrainingTaskKind.phrasePronunciation;
    final requireListening =
        forcedTaskKind == TrainingTaskKind.listening;
    final requireSpeech =
        forcedTaskKind == TrainingTaskKind.numberPronunciation;

    final availabilityContext = _availabilityContext(
      language: language,
      premiumPronunciationEnabled: premiumPronunciationEnabled,
    );
    final phraseAvailability = await _availabilityRegistry.check(
      TrainingTaskKind.phrasePronunciation,
      availabilityContext,
      force: requirePhrase,
    );
    final listeningAvailability = await _availabilityRegistry.check(
      TrainingTaskKind.listening,
      availabilityContext,
      force: requireListening,
    );
    final speechAvailability = await _availabilityRegistry.check(
      TrainingTaskKind.numberPronunciation,
      availabilityContext,
      force: requireSpeech,
    );

    if (requirePhrase && !phraseAvailability.isAvailable) {
      return TaskSchedulePaused(
        phraseAvailability.message ??
            'Premium pronunciation requires an internet connection.',
      );
    }
    if (requireListening && !listeningAvailability.isAvailable) {
      return TaskSchedulePaused(
        listeningAvailability.message ??
            'Text-to-speech is not available for the selected language.',
      );
    }
    if (requireSpeech && !speechAvailability.isAvailable) {
      return TaskSchedulePaused(
        speechAvailability.message ??
            'Speech recognition is not available on this device.',
      );
    }

    final allowPhrase = phraseAvailability.isAvailable || requirePhrase;
    final allowListening =
        listeningAvailability.isAvailable || requireListening;
    final allowSpeech = speechAvailability.isAvailable || requireSpeech;

    final picked = progressManager.pickNextCard(
      isEligible: (card) {
        if (forcedItemType != null && card.id.type != forcedItemType) {
          return false;
        }
        if (forcedTaskKind != null &&
            !forcedTaskKind.supportedItemTypes.contains(card.id.type)) {
          return false;
        }
        if (requirePhrase) {
          final numberValue = _resolveNumberValue(card);
          if (numberValue == null) return false;
          return _hasPhraseTemplate(language, numberValue);
        }
        return true;
      },
    );
    if (picked == null) {
      if (requirePhrase) {
        return const TaskSchedulePaused(
          'Phrase pronunciation tasks are not available for the selected language.',
        );
      }
      if (forcedItemType != null && forcedTaskKind != null) {
        return const TaskSchedulePaused(
          'Selected card type is not supported by the forced task.',
        );
      }
      if (forcedItemType != null) {
        return const TaskSchedulePaused(
          'Selected card type has no available cards.',
        );
      }
      if (forcedTaskKind != null) {
        return const TaskSchedulePaused(
          'Selected task is not available for this item.',
        );
      }
      return const TaskScheduleFinished();
    }

    final card = picked.card;
    final itemType = card.id.type;
    final numberValue = _resolveNumberValue(card);
    final canUsePhrase =
        allowPhrase &&
        TrainingTaskKind.phrasePronunciation.supportedItemTypes
            .contains(itemType) &&
        numberValue != null &&
        _hasPhraseTemplate(language, numberValue);
    if (requirePhrase && !canUsePhrase) {
      return const TaskSchedulePaused(
        'Phrase pronunciation tasks are not available for the selected language.',
      );
    }

    final canUseSpeechKind =
        allowSpeech &&
        TrainingTaskKind.numberPronunciation.supportedItemTypes
            .contains(itemType);
    final canUseListeningKind =
        allowListening &&
        TrainingTaskKind.listening.supportedItemTypes
            .contains(itemType);
    final canUseValueToTextKind =
        TrainingTaskKind.valueToText.supportedItemTypes.contains(itemType);
    final canUseTextToValueKind =
        TrainingTaskKind.textToValue.supportedItemTypes.contains(itemType);

    if (!canUseSpeechKind &&
        !canUseListeningKind &&
        !canUseValueToTextKind &&
        !canUseTextToValueKind &&
        !canUsePhrase) {
      return TaskSchedulePaused(
        speechAvailability.message ??
            'Speech recognition is not available on this device.',
      );
    }

    final taskKind =
        forcedTaskKind ??
        _pickTaskKind(
          canUsePhrase: canUsePhrase,
          canUseListening: canUseListeningKind,
          canUseSpeech: canUseSpeechKind,
          itemType: itemType,
        );

    return TaskScheduleReady(card: card, kind: taskKind);
  }

  TaskAvailabilityContext _availabilityContext({
    required LearningLanguage language,
    required bool premiumPronunciationEnabled,
  }) {
    return TaskAvailabilityContext(
      language: language,
      premiumPronunciationEnabled: premiumPronunciationEnabled,
      internetCheck: ({bool force = false}) async {
        await _internetGate.refresh(force: force);
        return _internetGate.hasInternet;
      },
    );
  }

  TrainingTaskKind _pickTaskKind({
    required bool canUsePhrase,
    required bool canUseListening,
    required bool canUseSpeech,
    required TrainingItemType itemType,
  }) {
    final weightedKinds = <MapEntry<TrainingTaskKind, int>>[
      if (canUseSpeech &&
          TrainingTaskKind.numberPronunciation.supportedItemTypes
              .contains(itemType))
        const MapEntry(
          TrainingTaskKind.numberPronunciation,
          _numberPronunciationWeight,
        ),
      if (TrainingTaskKind.valueToText.supportedItemTypes.contains(itemType))
        const MapEntry(
          TrainingTaskKind.valueToText,
          _valueToTextWeight,
        ),
      if (TrainingTaskKind.textToValue.supportedItemTypes.contains(itemType))
        const MapEntry(
          TrainingTaskKind.textToValue,
          _textToValueWeight,
        ),
      if (canUseListening &&
          TrainingTaskKind.listening.supportedItemTypes
              .contains(itemType))
        const MapEntry(
          TrainingTaskKind.listening,
          _listeningWeight,
        ),
      if (canUsePhrase &&
          TrainingTaskKind.phrasePronunciation.supportedItemTypes
              .contains(itemType))
        const MapEntry(
          TrainingTaskKind.phrasePronunciation,
          _phrasePronunciationWeight,
        ),
    ];
    final totalWeight =
        weightedKinds.fold(0, (sum, entry) => sum + entry.value);
    final roll = _random.nextInt(totalWeight);
    var cursor = 0;
    for (final entry in weightedKinds) {
      cursor += entry.value;
      if (roll < cursor) {
        return entry.key;
      }
    }
    return weightedKinds.last.key;
  }

  bool _hasPhraseTemplate(LearningLanguage language, int numberValue) {
    return _languageRouter.hasTemplate(numberValue, language: language);
  }

  int? _resolveNumberValue(PronunciationTaskData card) {
    return card.numberValue;
  }
}
