import 'dart:math';

import 'language_router.dart';
import 'learning_language.dart';
import 'progress_manager.dart';
import 'session_helpers.dart';
import 'task_availability.dart';
import 'training_services.dart';
import 'training_task.dart';
import 'tasks/number_pronunciation_task.dart';
import 'training_item.dart';

sealed class TaskScheduleResult {
  const TaskScheduleResult();
}

final class TaskScheduleReady extends TaskScheduleResult {
  const TaskScheduleReady({
    required this.card,
    required this.kind,
  });

  final NumberPronunciationTask card;
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
  static const int _numberToWordWeight = 15;
  static const int _wordToNumberWeight = 15;
  static const int _listeningNumbersWeight = 15;
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
      TrainingTaskKind.listeningNumbers,
      context,
      force: true,
    );
  }

  Future<TaskScheduleResult> scheduleNext({
    required ProgressManager progressManager,
    required LearningLanguage language,
    required bool premiumPronunciationEnabled,
    TrainingTaskKind? forcedTaskKind,
  }) async {
    if (!progressManager.hasRemainingCards) {
      return const TaskScheduleFinished();
    }

    final requirePhrase =
        forcedTaskKind == TrainingTaskKind.phrasePronunciation;
    final requireListening =
        forcedTaskKind == TrainingTaskKind.listeningNumbers;
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
      TrainingTaskKind.listeningNumbers,
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
        if (forcedTaskKind != null &&
            !forcedTaskKind.supportedItemTypes.contains(card.id.type)) {
          return false;
        }
        if (requirePhrase) {
          return _hasPhraseTemplate(language, card.numberValue);
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
      if (forcedTaskKind != null) {
        return const TaskSchedulePaused(
          'Selected task is not available for this item.',
        );
      }
      return const TaskScheduleFinished();
    }

    final card = picked.card;
    final itemType = card.id.type;
    final canUsePhrase =
        allowPhrase &&
        TrainingTaskKind.phrasePronunciation.supportedItemTypes
            .contains(itemType) &&
        _hasPhraseTemplate(language, card.numberValue);
    if (requirePhrase && !canUsePhrase) {
      return const TaskSchedulePaused(
        'Phrase pronunciation tasks are not available for the selected language.',
      );
    }

    final taskKind =
        forcedTaskKind ??
        _pickTaskKind(
          canUsePhrase: canUsePhrase,
          canUseListening: allowListening,
          canUseSpeech: allowSpeech,
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
      if (TrainingTaskKind.numberToWord.supportedItemTypes.contains(itemType))
        const MapEntry(
          TrainingTaskKind.numberToWord,
          _numberToWordWeight,
        ),
      if (TrainingTaskKind.wordToNumber.supportedItemTypes.contains(itemType))
        const MapEntry(
          TrainingTaskKind.wordToNumber,
          _wordToNumberWeight,
        ),
      if (canUseListening &&
          TrainingTaskKind.listeningNumbers.supportedItemTypes
              .contains(itemType))
        const MapEntry(
          TrainingTaskKind.listeningNumbers,
          _listeningNumbersWeight,
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
}
