import 'dart:math';

import 'base_language_profile.dart';
import 'matcher/matcher_tokenizer.dart';
import 'training/domain/learning_language.dart';

enum ExerciseDifficultyTier { easy, medium, hard }

enum ExerciseMode {
  speak,
  chooseFromPrompt,
  chooseFromAnswer,
  listenAndChoose,
  reviewPronunciation,
}

extension ExerciseModeX on ExerciseMode {
  String get label {
    switch (this) {
      case ExerciseMode.speak:
        return 'Speak';
      case ExerciseMode.chooseFromPrompt:
        return 'Choose from prompt';
      case ExerciseMode.chooseFromAnswer:
        return 'Choose from answer';
      case ExerciseMode.listenAndChoose:
        return 'Listen and choose';
      case ExerciseMode.reviewPronunciation:
        return 'Pronunciation review';
    }
  }

  bool get usesTimer {
    return this != ExerciseMode.reviewPronunciation;
  }
}

class ExerciseId implements Comparable<ExerciseId> {
  const ExerciseId({
    required this.moduleId,
    required this.familyId,
    required this.variantId,
  });

  final String moduleId;
  final String familyId;
  final String variantId;

  String get storageKey => '$moduleId/$familyId/$variantId';

  @override
  int compareTo(ExerciseId other) {
    return storageKey.compareTo(other.storageKey);
  }

  @override
  String toString() => storageKey;

  @override
  bool operator ==(Object other) {
    return other is ExerciseId &&
        other.moduleId == moduleId &&
        other.familyId == familyId &&
        other.variantId == variantId;
  }

  @override
  int get hashCode => Object.hash(moduleId, familyId, variantId);
}

class ExerciseFamily {
  ExerciseFamily({
    required this.moduleId,
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.difficultyTier,
    required this.defaultDuration,
    required List<ExerciseMode> supportedModes,
    this.masteryAccuracy,
  }) : supportedModes = List<ExerciseMode>.unmodifiable(supportedModes);

  final String moduleId;
  final String id;
  final String label;
  final String shortLabel;
  final ExerciseDifficultyTier difficultyTier;
  final Duration defaultDuration;
  final List<ExerciseMode> supportedModes;
  final double? masteryAccuracy;

  String get storageKey => '$moduleId/$id';
}

class ChoiceExerciseSpec {
  ChoiceExerciseSpec({
    required this.prompt,
    required this.correctOption,
    required List<String> options,
  }) : options = List<String>.unmodifiable(options);

  final String prompt;
  final String correctOption;
  final List<String> options;
}

class ListeningExerciseSpec {
  ListeningExerciseSpec({
    required this.speechText,
    required this.correctOption,
    required List<String> options,
  }) : options = List<String>.unmodifiable(options);

  final String speechText;
  final String correctOption;
  final List<String> options;
}

class ReviewPronunciationSpec {
  const ReviewPronunciationSpec({required this.expectedText});

  final String expectedText;
}

class ExerciseMatcherConfig {
  const ExerciseMatcherConfig({this.promptAliases = const <String>[]});

  final List<String> promptAliases;
}

typedef DynamicExerciseResolver = ExerciseCard Function();

class ExerciseCard {
  ExerciseCard({
    required this.id,
    ExerciseId? progressId,
    required this.family,
    required this.language,
    required this.displayText,
    required this.promptText,
    required List<String> acceptedAnswers,
    required this.celebrationText,
    this.matcherConfig = const ExerciseMatcherConfig(),
    this.chooseFromPrompt,
    this.chooseFromAnswer,
    this.listenAndChoose,
    this.reviewPronunciation,
    this.dynamicResolver,
  }) : progressId = progressId ?? id,
       acceptedAnswers = List<String>.unmodifiable(acceptedAnswers);

  final ExerciseId id;
  final ExerciseId progressId;
  final ExerciseFamily family;
  final LearningLanguage language;
  final String displayText;
  final String promptText;
  final List<String> acceptedAnswers;
  final String celebrationText;
  final ExerciseMatcherConfig matcherConfig;
  final ChoiceExerciseSpec? chooseFromPrompt;
  final ChoiceExerciseSpec? chooseFromAnswer;
  final ListeningExerciseSpec? listenAndChoose;
  final ReviewPronunciationSpec? reviewPronunciation;
  final DynamicExerciseResolver? dynamicResolver;

  ExerciseCard resolveDynamic() {
    return dynamicResolver?.call() ?? this;
  }
}

class CatalogSnapshot {
  CatalogSnapshot({
    required List<ExerciseCard> cards,
    required Map<String, ExerciseFamily> familiesByKey,
  }) : cards = List<ExerciseCard>.unmodifiable(cards),
       familiesByKey = Map<String, ExerciseFamily>.unmodifiable(familiesByKey);

  final List<ExerciseCard> cards;
  final Map<String, ExerciseFamily> familiesByKey;
}

abstract class TrainingModule {
  String get moduleId;
  String get displayName;

  bool supportsLanguage(LearningLanguage language);

  List<ExerciseFamily> buildFamilies(LearningLanguage language);

  List<ExerciseCard> buildCards(LearningLanguage language);
}

class ExerciseCatalog {
  ExerciseCatalog({required List<TrainingModule> modules})
    : _modules = List<TrainingModule>.unmodifiable(modules);

  final List<TrainingModule> _modules;

  CatalogSnapshot build(LearningLanguage language) {
    final families = <String, ExerciseFamily>{};
    final cards = <ExerciseCard>[];
    for (final module in _modules) {
      if (!module.supportsLanguage(language)) {
        continue;
      }
      for (final family in module.buildFamilies(language)) {
        families[family.storageKey] = family;
      }
      cards.addAll(module.buildCards(language));
    }
    cards.sort((left, right) => left.id.compareTo(right.id));
    return CatalogSnapshot(cards: cards, familiesByKey: families);
  }
}

typedef LanguageProfileResolver =
    BaseLanguageProfile Function(LearningLanguage language);

typedef MatcherTokenizerResolver =
    MatcherTokenizer Function(LearningLanguage language);

typedef RandomFactory = Random Function();
