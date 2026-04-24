import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

const _moduleId = 'test';

final _easyFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'easy_family',
  label: 'Easy',
  shortLabel: 'Easy',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: Duration(seconds: 15),
  supportedModes: [ExerciseMode.speak],
);

final _phoneFamily = ExerciseFamily(
  moduleId: _moduleId,
  id: 'phone_family',
  label: 'Phone',
  shortLabel: 'Phone',
  difficultyTier: ExerciseDifficultyTier.hard,
  defaultDuration: Duration(seconds: 30),
  supportedModes: [ExerciseMode.speak],
  masteryAccuracy: 0.8,
);

ExerciseCard _card({
  required ExerciseFamily family,
  String prompt = 'five',
  List<String> answers = const <String>['five', 'fai-v'],
  DynamicExerciseResolver? dynamicResolver,
}) {
  return ExerciseCard(
    id: ExerciseId(moduleId: _moduleId, familyId: family.id, variantId: 'test'),
    family: family,
    language: LearningLanguage.english,
    displayText: '5',
    promptText: prompt,
    acceptedAnswers: answers,
    celebrationText: '5 -> fai-v',
    dynamicResolver: dynamicResolver,
  );
}

void main() {
  const flow = TaskCardFlow();

  group('resolveDynamicCard', () {
    test('static card returns itself unchanged', () {
      final card = _card(family: _easyFamily);
      final resolved = flow.resolveDynamicCard(card);
      expect(resolved.displayText, card.displayText);
      expect(resolved.promptText, card.promptText);
    });

    test('dynamic card returns new card from resolver', () {
      var callCount = 0;
      ExerciseCard resolver() {
        callCount++;
        return _card(
          family: _easyFamily,
          prompt: 'prompt_$callCount',
          answers: ['answer_$callCount'],
        );
      }

      final card = _card(family: _easyFamily, dynamicResolver: resolver);
      final first = flow.resolveDynamicCard(card);
      final second = flow.resolveDynamicCard(card);

      expect(first.promptText, 'prompt_1');
      expect(second.promptText, 'prompt_2');
      expect(first.promptText, isNot(equals(second.promptText)));
    });
  });

  group('resolveHintText', () {
    test('returns hint for speak mode when below streak threshold', () {
      final card = _card(family: _easyFamily);
      final hint = flow.resolveHintText(
        card: card,
        mode: ExerciseMode.speak,
        consecutiveCorrect: 0,
        hintVisibleUntilCorrectStreak: 10,
      );
      expect(hint, 'fai-v');
    });

    test('returns null for speak mode when at or above streak threshold', () {
      final card = _card(family: _easyFamily);
      final hint = flow.resolveHintText(
        card: card,
        mode: ExerciseMode.speak,
        consecutiveCorrect: 10,
        hintVisibleUntilCorrectStreak: 10,
      );
      expect(hint, isNull);
    });

    test('returns null for chooseFromPrompt mode', () {
      final card = _card(family: _easyFamily);
      final hint = flow.resolveHintText(
        card: card,
        mode: ExerciseMode.chooseFromPrompt,
        consecutiveCorrect: 0,
        hintVisibleUntilCorrectStreak: 10,
      );
      expect(hint, isNull);
    });

    test('returns hint for reviewPronunciation mode', () {
      final card = _card(family: _easyFamily);
      final hint = flow.resolveHintText(
        card: card,
        mode: ExerciseMode.reviewPronunciation,
        consecutiveCorrect: 0,
        hintVisibleUntilCorrectStreak: 10,
      );
      expect(hint, 'fai-v');
    });
  });

  group('LearningParams', () {
    test('hintVisibleUntilCorrectStreak: easy=10, hard=7', () {
      final params = LearningParams.defaults();
      expect(
        params.hintVisibleUntilCorrectStreak(ExerciseDifficultyTier.easy),
        10,
      );
      expect(
        params.hintVisibleUntilCorrectStreak(ExerciseDifficultyTier.hard),
        7,
      );
    });

    test('hintVisibleUntilCorrectStreakForFamily: phone family (0.8) = 8', () {
      final params = LearningParams.defaults();
      expect(params.hintVisibleUntilCorrectStreakForFamily(_phoneFamily), 8);
    });
  });
}
