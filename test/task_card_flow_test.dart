import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/language_router.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/learning_strategy/learning_params.dart';
import 'package:number_gym/features/training/domain/task_card_flow.dart';
import 'package:number_gym/features/training/domain/time_value.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';

import 'helpers/training_fakes.dart';

void main() {
  test(
    'resolveDynamicCard creates random time tasks for random-time cards',
    () {
      final settings = FakeSettingsRepository();
      final languageRouter = LanguageRouter(
        settingsRepository: settings,
        random: Random(1),
      );
      final flow = TaskCardFlow(
        random: Random(2),
        languageRouter: languageRouter,
      );
      final card = _FakeCard(
        id: const TrainingItemId(type: TrainingItemType.timeRandom),
        prompt: '00:00',
        answers: const <String>['00:00'],
        language: LearningLanguage.english,
      );

      final first = flow.resolveDynamicCard(card, LearningLanguage.english);
      final second = flow.resolveDynamicCard(card, LearningLanguage.english);

      expect(first.id, card.id);
      expect(first.timeValue, isNotNull);
      expect(second.timeValue, isNotNull);
      expect(second.timeValue, isNot(equals(first.timeValue)));
    },
  );

  test(
    'phrase tasks reuse number hint rule with fixed mastery-based gating',
    () {
      final settings = FakeSettingsRepository();
      final languageRouter = LanguageRouter(
        settingsRepository: settings,
        random: Random(3),
      );
      final flow = TaskCardFlow(
        random: Random(4),
        languageRouter: languageRouter,
      );
      final card = _FakeCard(
        id: const TrainingItemId(type: TrainingItemType.digits, number: 5),
        prompt: 'five',
        answers: const <String>['five', 'fai-v'],
        language: LearningLanguage.english,
        numberValue: 5,
      );

      expect(
        flow.resolveHintText(
          card: card,
          method: LearningMethod.phrasePronunciation,
          consecutiveCorrect: 0,
          hintVisibleUntilCorrectStreak: 10,
        ),
        'fai-v',
      );
      expect(
        flow.resolveHintText(
          card: card,
          method: LearningMethod.numberPronunciation,
          consecutiveCorrect: 10,
          hintVisibleUntilCorrectStreak: 10,
        ),
        isNull,
      );
      expect(
        flow.resolveHintText(
          card: card,
          method: LearningMethod.valueToText,
          consecutiveCorrect: 0,
          hintVisibleUntilCorrectStreak: 10,
        ),
        isNull,
      );
      expect(
        flow.resolveHintText(
          card: card,
          method: LearningMethod.numberPronunciation,
          consecutiveCorrect: 0,
          hintVisibleUntilCorrectStreak: 10,
        ),
        'fai-v',
      );

      const params = LearningParams(
        dailyAttemptLimit: 50,
        dailyNewCardsLimit: 15,
        clusterMaxGapMinutes: 30,
        maxStoredClusters: 32,
        recentAttemptsWindow: 10,
        minAttemptsToLearn: 20,
        repeatCooldownCards: 2,
        easyMasteryAccuracy: 1.0,
        mediumMasteryAccuracy: 0.85,
        hardMasteryAccuracy: 0.75,
        easyTypeWeight: 1.8,
        mediumTypeWeight: 1.1,
        hardTypeWeight: 0.7,
        weaknessBoost: 2.0,
        newCardBoost: 1.4,
        recentMistakeBoost: 1.3,
        cooldownPenalty: 0.2,
      );
      expect(params.hintVisibleUntilCorrectStreak(TrainingItemType.digits), 10);
      expect(
        params.hintVisibleUntilCorrectStreak(TrainingItemType.phone33x3),
        8,
      );
    },
  );
}

class _FakeCard implements PronunciationTaskData {
  const _FakeCard({
    required this.id,
    required this.prompt,
    required this.answers,
    required this.language,
    this.numberValue,
  });

  @override
  final TrainingItemId id;

  @override
  TrainingItemId get progressId => id;

  @override
  final int? numberValue;

  @override
  TimeValue? get timeValue => null;

  @override
  String get displayText => prompt;

  @override
  final String prompt;

  @override
  final List<String> answers;

  @override
  final LearningLanguage language;

  @override
  MultipleChoiceSpec buildValueToTextSpec(MultipleChoiceBuildContext context) {
    throw UnimplementedError();
  }
}
