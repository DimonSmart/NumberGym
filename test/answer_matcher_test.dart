import 'package:flutter_test/flutter_test.dart';

import 'package:number_gym/features/training/domain/learning_language.dart';
import 'package:number_gym/features/training/domain/services/answer_matcher.dart';

void main() {
  test('matches time with o clock alias', () {
    final matcher = AnswerMatcher();
    matcher.reset(
      prompt: '12:00',
      answers: const <String>[],
      language: LearningLanguage.english,
    );

    final result = matcher.applyRecognition('12 o clock');

    expect(result.matchedSegmentIndices, equals([0]));
    expect(matcher.isComplete, isTrue);
  });

  test('continues matching after correction', () {
    final matcher = AnswerMatcher();
    matcher.reset(
      prompt: '12 20',
      answers: const <String>[],
      language: LearningLanguage.english,
    );

    final first = matcher.applyRecognition('12 30');
    expect(first.matchedSegmentIndices, equals([0]));
    expect(matcher.matchedTokens, equals([true, false]));

    final second = matcher.applyRecognition('20');
    expect(second.matchedSegmentIndices, equals([1]));
    expect(matcher.isComplete, isTrue);
  });

  test('matches only the first duplicate', () {
    final matcher = AnswerMatcher();
    matcher.reset(
      prompt: '50 50',
      answers: const <String>[],
      language: LearningLanguage.english,
    );

    final result = matcher.applyRecognition('50');

    expect(result.matchedSegmentIndices, equals([0]));
    expect(matcher.matchedTokens, equals([true, false]));
  });

  test('skips extra words between expected numbers', () {
    final matcher = AnswerMatcher();
    matcher.reset(
      prompt: '11 120',
      answers: const <String>[],
      language: LearningLanguage.english,
    );

    final result = matcher.applyRecognition('11 and maybe 120');

    expect(result.matchedSegmentIndices, equals([0, 1]));
    expect(matcher.isComplete, isTrue);
  });

  test('accepts repeated speech echo for spanish digit', () {
    final matcher = AnswerMatcher();
    matcher.reset(
      prompt: '6',
      answers: const <String>['seis', '6'],
      language: LearningLanguage.spanish,
    );

    final result = matcher.applyRecognition('seis seis');

    expect(result.matchedSegmentIndices, equals([0]));
    expect(matcher.isComplete, isTrue);
  });

  test('does not collapse spanish unit chain into arithmetic sum', () {
    final matcher = AnswerMatcher();
    matcher.reset(
      prompt: '6',
      answers: const <String>['seis', '6'],
      language: LearningLanguage.spanish,
    );

    final result = matcher.applyRecognition('uno dos tres');

    expect(result.matchedSegmentIndices, isEmpty);
    expect(matcher.isComplete, isFalse);
  });

  test('accepts repeated spanish composite number phrase', () {
    final matcher = AnswerMatcher();
    matcher.reset(
      prompt: '96',
      answers: const <String>['noventa y seis', '96'],
      language: LearningLanguage.spanish,
    );

    final result = matcher.applyRecognition('noventa y seis noventa y seis');

    expect(result.matchedSegmentIndices, equals([0]));
    expect(matcher.isComplete, isTrue);
  });
}
