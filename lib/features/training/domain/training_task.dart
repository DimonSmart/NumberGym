import 'learning_language.dart';
import 'training_item.dart';

enum TrainingTaskKind {
  numberPronunciation,
  numberToWord, // Formerly numberReading
  wordToNumber, // New inverse variant
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
      case TrainingTaskKind.listeningNumbers:
        return true;
    }
  }

  Set<TrainingItemType> get supportedItemTypes {
    switch (this) {
      case TrainingTaskKind.numberPronunciation:
      case TrainingTaskKind.numberToWord:
      case TrainingTaskKind.wordToNumber:
      case TrainingTaskKind.listeningNumbers:
      case TrainingTaskKind.phrasePronunciation:
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
  String get displayText;
  String get prompt;
  List<String> get answers;
  LearningLanguage get language;
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
