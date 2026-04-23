import 'dart:math' as math;

import '../data/phone_cards.dart';
import 'language_router.dart';
import 'learning_language.dart';
import 'training_item.dart';
import 'training_task.dart';
import 'tasks/time_pronunciation_task.dart';
import 'time_value.dart';

class TaskCardFlow {
  TaskCardFlow({
    required math.Random random,
    required LanguageRouter languageRouter,
  }) : _random = random,
       _languageRouter = languageRouter;

  final math.Random _random;
  final LanguageRouter _languageRouter;

  TimeValue? _lastRandomTimeValue;
  final Map<TrainingItemType, int> _lastRandomPhoneValueByType =
      <TrainingItemType, int>{};

  PronunciationTaskData resolveDynamicCard(
    PronunciationTaskData card,
    LearningLanguage language,
  ) {
    final withRandomTime = _resolveRandomTimeCard(card, language);
    return _resolveRandomPhoneCard(withRandomTime, language);
  }

  String? resolveHintText({
    required PronunciationTaskData card,
    required LearningMethod method,
    required int consecutiveCorrect,
    required int hintVisibleUntilCorrectStreak,
  }) {
    final direct = _resolveHintForMethod(
      card: card,
      method: method,
      consecutiveCorrect: consecutiveCorrect,
      hintVisibleUntilCorrectStreak: hintVisibleUntilCorrectStreak,
    );
    if (direct != null) {
      return direct;
    }
    if (method == LearningMethod.phrasePronunciation) {
      return _resolveHintForMethod(
        card: card,
        method: LearningMethod.numberPronunciation,
        consecutiveCorrect: consecutiveCorrect,
        hintVisibleUntilCorrectStreak: hintVisibleUntilCorrectStreak,
      );
    }
    return null;
  }

  String? _resolveHintForMethod({
    required PronunciationTaskData card,
    required LearningMethod method,
    required int consecutiveCorrect,
    required int hintVisibleUntilCorrectStreak,
  }) {
    if (method != LearningMethod.numberPronunciation) {
      return null;
    }
    if (hintVisibleUntilCorrectStreak <= 0 ||
        consecutiveCorrect >= hintVisibleUntilCorrectStreak) {
      return null;
    }

    final answers = card.answers;
    if (answers.isEmpty) {
      return null;
    }

    final prompt = card.prompt.trim().toLowerCase();
    for (final answer in answers) {
      final trimmed = answer.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (prompt.isNotEmpty && trimmed.toLowerCase() == prompt) {
        continue;
      }
      return trimmed;
    }

    final fallback = answers.first.trim();
    return fallback.isEmpty ? null : fallback;
  }

  PronunciationTaskData _resolveRandomTimeCard(
    PronunciationTaskData card,
    LearningLanguage language,
  ) {
    if (card.id.type != TrainingItemType.timeRandom) {
      return card;
    }

    final timeValue = _nextRandomTimeValue();
    return TimePronunciationTask.forTime(
      id: card.id,
      timeValue: timeValue,
      language: language,
      toWords: (value) =>
          _languageRouter.timeToWords(value, language: language),
    );
  }

  PronunciationTaskData _resolveRandomPhoneCard(
    PronunciationTaskData card,
    LearningLanguage language,
  ) {
    switch (card.id.type) {
      case TrainingItemType.phone33x3:
      case TrainingItemType.phone3222:
      case TrainingItemType.phone2322:
        final previous = _lastRandomPhoneValueByType[card.id.type];
        late PronunciationTaskData dynamicCard;
        var attempts = 0;
        do {
          dynamicCard = buildRandomPhoneCard(
            id: card.id,
            language: language,
            random: _random,
            toWords: _languageRouter.numberWordsConverter(language),
          );
          attempts += 1;
        } while (previous != null &&
            dynamicCard.numberValue == previous &&
            attempts < 8);
        final numberValue = dynamicCard.numberValue;
        if (numberValue != null) {
          _lastRandomPhoneValueByType[card.id.type] = numberValue;
        }
        return dynamicCard;
      default:
        return card;
    }
  }

  TimeValue _nextRandomTimeValue() {
    late TimeValue candidate;
    var attempts = 0;
    do {
      candidate = TimeValue(
        hour: _random.nextInt(24),
        minute: _random.nextInt(60),
      );
      attempts += 1;
    } while (_lastRandomTimeValue == candidate && attempts < 8);
    _lastRandomTimeValue = candidate;
    return candidate;
  }
}
