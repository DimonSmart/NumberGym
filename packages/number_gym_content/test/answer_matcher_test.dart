import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym_content/src/languages/registry.dart';
import 'package:number_gym_content/src/number_gym_matcher_tokenizer.dart';
import 'package:trainer_core/trainer_core.dart';

AnswerMatcher _matcher(LearningLanguage language) {
  final pack = LanguageRegistry.of(language);
  return AnswerMatcher(
    normalizer: pack.normalizer,
    tokenizer: NumberGymMatcherTokenizer(pack),
  );
}

void main() {
  test('matches time with o clock alias', () {
    final matcher = _matcher(LearningLanguage.english)
      ..reset(
        prompt: '12:00',
        answers: const <String>[],
        promptAliases: const <String>['12 o clock'],
      );

    final result = matcher.applyRecognition('12 o clock');

    expect(result.matchedSegmentIndices, isNotEmpty);
    expect(matcher.isComplete, isTrue);
  });

  test('continues matching after correction', () {
    final matcher = _matcher(LearningLanguage.english)
      ..reset(
        prompt: '12 20',
        answers: const <String>[],
        promptAliases: const <String>[],
      );

    final first = matcher.applyRecognition('12 30');
    expect(first.matchedSegmentIndices, equals([0]));
    expect(matcher.matchedTokens, equals([true, false]));

    final second = matcher.applyRecognition('20');
    expect(second.matchedSegmentIndices, equals([1]));
    expect(matcher.isComplete, isTrue);
  });

  test('matches only the first duplicate', () {
    final matcher = _matcher(LearningLanguage.english)
      ..reset(
        prompt: '50 50',
        answers: const <String>[],
        promptAliases: const <String>[],
      );

    final result = matcher.applyRecognition('50');

    expect(result.matchedSegmentIndices, equals([0]));
    expect(matcher.matchedTokens, equals([true, false]));
  });

  test('skips extra words between expected numbers', () {
    final matcher = _matcher(LearningLanguage.english)
      ..reset(
        prompt: '11 120',
        answers: const <String>[],
        promptAliases: const <String>[],
      );

    final result = matcher.applyRecognition('11 and maybe 120');

    expect(result.matchedSegmentIndices, equals([0, 1]));
    expect(matcher.isComplete, isTrue);
  });

  test('accepts repeated speech echo for spanish digit', () {
    final matcher = _matcher(LearningLanguage.spanish)
      ..reset(
        prompt: '6',
        answers: const <String>['seis', '6'],
        promptAliases: const <String>[],
      );

    final result = matcher.applyRecognition('seis seis');

    expect(result.matchedSegmentIndices, equals([0]));
    expect(matcher.isComplete, isTrue);
  });

  test('checks accepted answer without mutating matcher state', () {
    final matcher = _matcher(LearningLanguage.spanish)
      ..reset(
        prompt: '6',
        answers: const <String>['seis', '6'],
        promptAliases: const <String>[],
      );

    expect(matcher.isAcceptedAnswer('seis'), isTrue);
    expect(matcher.isAcceptedAnswer(' 6 '), isTrue);
    expect(matcher.isAcceptedAnswer('siete'), isFalse);
    expect(matcher.isComplete, isFalse);
  });

  test('does not collapse spanish unit chain into arithmetic sum', () {
    final matcher = _matcher(LearningLanguage.spanish)
      ..reset(
        prompt: '6',
        answers: const <String>['seis', '6'],
        promptAliases: const <String>[],
      );

    final result = matcher.applyRecognition('uno dos tres');

    expect(result.matchedSegmentIndices, isEmpty);
    expect(matcher.isComplete, isFalse);
  });

  test('accepts repeated spanish composite number phrase', () {
    final matcher = _matcher(LearningLanguage.spanish)
      ..reset(
        prompt: '96',
        answers: const <String>['noventa y seis', '96'],
        promptAliases: const <String>[],
      );

    final result = matcher.applyRecognition('noventa y seis noventa y seis');

    expect(result.matchedSegmentIndices, equals([0]));
    expect(matcher.isComplete, isTrue);
  });
}
