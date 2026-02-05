import 'dart:math';

import 'learning_language.dart';
import 'time_value.dart';
import 'training_item.dart';

enum TrainingTaskKind {
  numberPronunciation,
  numberToWord, // Formerly numberReading
  wordToNumber, // Inverse for number cards
  wordToTime, // Inverse for time cards
  listeningNumbers,
  phrasePronunciation,
}

extension TrainingTaskKindX on TrainingTaskKind {
  String get label {
    switch (this) {
      case TrainingTaskKind.numberPronunciation:
        return 'Number pronunciation';
      case TrainingTaskKind.numberToWord:
        return 'Select the word';
      case TrainingTaskKind.wordToNumber:
        return 'Select the number';
      case TrainingTaskKind.wordToTime:
        return 'Select the time';
      case TrainingTaskKind.listeningNumbers:
        return 'Listening numbers';
      case TrainingTaskKind.phrasePronunciation:
        return 'Phrase pronunciation';
    }
  }

  bool get usesTimer {
    switch (this) {
      case TrainingTaskKind.phrasePronunciation:
        return false;
      case TrainingTaskKind.numberPronunciation:
      case TrainingTaskKind.numberToWord:
      case TrainingTaskKind.wordToNumber:
      case TrainingTaskKind.wordToTime:
      case TrainingTaskKind.listeningNumbers:
        return true;
    }
  }

  Set<TrainingItemType> get supportedItemTypes {
    switch (this) {
      case TrainingTaskKind.numberPronunciation:
        return const {
          TrainingItemType.digits,
          TrainingItemType.base,
          TrainingItemType.hundreds,
          TrainingItemType.thousands,
          TrainingItemType.timeExact,
          TrainingItemType.timeQuarter,
          TrainingItemType.timeHalf,
          TrainingItemType.timeRandom,
        };
      case TrainingTaskKind.numberToWord:
        return const {
          TrainingItemType.digits,
          TrainingItemType.base,
          TrainingItemType.hundreds,
          TrainingItemType.thousands,
          TrainingItemType.timeExact,
          TrainingItemType.timeQuarter,
          TrainingItemType.timeHalf,
          TrainingItemType.timeRandom,
        };
      case TrainingTaskKind.wordToNumber:
      case TrainingTaskKind.listeningNumbers:
      case TrainingTaskKind.phrasePronunciation:
        return const {
          TrainingItemType.digits,
          TrainingItemType.base,
          TrainingItemType.hundreds,
          TrainingItemType.thousands,
        };
      case TrainingTaskKind.wordToTime:
        return const {
          TrainingItemType.timeExact,
          TrainingItemType.timeQuarter,
          TrainingItemType.timeHalf,
          TrainingItemType.timeRandom,
        };
    }
  }
}

abstract class TrainingTask {
  final TrainingItemId id;
  final TrainingTaskKind kind;

  const TrainingTask({
    required this.id,
    required this.kind,
  });

  /// Key used to track progress; by default equals [id].
  TrainingItemId get progressId => id;

  /// Number value the task is built around.
  int? get numberValue;

  /// Text shown to the learner.
  String get displayText;
}

abstract class PronunciationTaskData {
  TrainingItemId get id;
  TrainingItemId get progressId;
  int? get numberValue;
  TimeValue? get timeValue;
  String get displayText;
  String get prompt;
  List<String> get answers;
  LearningLanguage get language;
  MultipleChoiceSpec buildNumberToWordSpec(MultipleChoiceBuildContext context);
}

class MultipleChoiceSpec {
  MultipleChoiceSpec({
    required this.prompt,
    required this.correctOption,
    required List<String> options,
    required this.numberValue,
  }) : options = List<String>.unmodifiable(options);

  final String prompt;
  final String correctOption;
  final List<String> options;
  final int? numberValue;
}

abstract class MultipleChoiceBuildContext {
  LearningLanguage get language;
  List<TrainingItemId> get cardIds;
  String Function(int) get toWords;
  String Function(TimeValue) get timeToWords;
  Random get random;
}

abstract class NumberTrainingTask extends TrainingTask {
  @override
  final int numberValue;

  const NumberTrainingTask({
    required super.id,
    required super.kind,
    required this.numberValue,
  });
}
