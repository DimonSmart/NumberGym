import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/language_router.dart';
import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/task_card_flow.dart';
import 'package:number_gym/features/training/domain/time_value.dart';
import 'package:number_gym/features/training/domain/training_item.dart';
import 'package:number_gym/features/training/domain/training_task.dart';

import 'helpers/training_fakes.dart';

void main() {
  test('resolveDynamicCard creates random time tasks for random-time cards', () {
    final settings = FakeSettingsRepository();
    final languageRouter = LanguageRouter(
      settingsRepository: settings,
      random: Random(1),
    );
    final flow = TaskCardFlow(
      random: Random(2),
      languageRouter: languageRouter,
      settingsRepository: settings,
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
  });

  test('phrase tasks reuse number hint rule with streak gating', () {
    final settings = FakeSettingsRepository(hintStreak: 3);
    final languageRouter = LanguageRouter(
      settingsRepository: settings,
      random: Random(3),
    );
    final flow = TaskCardFlow(
      random: Random(4),
      languageRouter: languageRouter,
      settingsRepository: settings,
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
        currentStreak: 0,
      ),
      'fai-v',
    );
    expect(
      flow.resolveHintText(
        card: card,
        method: LearningMethod.numberPronunciation,
        currentStreak: 3,
      ),
      isNull,
    );
    expect(
      flow.resolveHintText(
        card: card,
        method: LearningMethod.valueToText,
        currentStreak: 0,
      ),
      isNull,
    );
  });
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
