import 'dart:math';

import 'learning_language.dart';
import 'time_value.dart';
import 'training_item.dart';

enum LearningMethod {
  numberPronunciation,
  valueToText, // Formerly numberReading
  textToValue, // Inverse for number/time cards
  listening,
  phrasePronunciation,
}

extension LearningMethodX on LearningMethod {
  String get label {
    switch (this) {
      case LearningMethod.numberPronunciation:
        return 'Number pronunciation';
      case LearningMethod.valueToText:
        return 'Value to text';
      case LearningMethod.textToValue:
        return 'Text to value';
      case LearningMethod.listening:
        return 'Listening';
      case LearningMethod.phrasePronunciation:
        return 'Phrase pronunciation';
    }
  }

  bool get usesTimer {
    switch (this) {
      case LearningMethod.phrasePronunciation:
        return false;
      case LearningMethod.numberPronunciation:
      case LearningMethod.valueToText:
      case LearningMethod.textToValue:
      case LearningMethod.listening:
        return true;
    }
  }

  Set<TrainingItemType> get supportedItemTypes {
    switch (this) {
      case LearningMethod.numberPronunciation:
        return const {
          TrainingItemType.digits,
          TrainingItemType.base,
          TrainingItemType.hundreds,
          TrainingItemType.thousands,
          TrainingItemType.timeExact,
          TrainingItemType.timeQuarter,
          TrainingItemType.timeHalf,
          TrainingItemType.timeRandom,
          TrainingItemType.phone33x3,
          TrainingItemType.phone3222,
          TrainingItemType.phone2322,
        };
      case LearningMethod.valueToText:
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
      case LearningMethod.textToValue:
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
      case LearningMethod.listening:
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
      case LearningMethod.phrasePronunciation:
        return const {
          TrainingItemType.digits,
          TrainingItemType.base,
          TrainingItemType.hundreds,
          TrainingItemType.thousands,
        };
    }
  }
}

abstract class TrainingTask {
  final TrainingItemId id;
  final LearningMethod kind;

  const TrainingTask({required this.id, required this.kind});

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
  MultipleChoiceSpec buildValueToTextSpec(MultipleChoiceBuildContext context);
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
