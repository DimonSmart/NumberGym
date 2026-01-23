enum TrainingTaskKind {
  numberPronunciation,
  numberToWord, // Formerly numberReading
  wordToNumber, // New inverse variant
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
      case TrainingTaskKind.phrasePronunciation:
        return 'Phrase pronunciation';
    }
  }
}

abstract class TrainingTask {
  final int id;
  final TrainingTaskKind kind;

  const TrainingTask({
    required this.id,
    required this.kind,
  });

  /// Key used to track progress; by default equals [id].
  int get progressId => id;

  /// Number value the task is built around.
  int get numberValue;

  /// Text shown to the learner.
  String get displayText;
}

abstract class NumberTrainingTask extends TrainingTask {
  @override
  final int numberValue;

  const NumberTrainingTask({
    required super.id,
    required super.kind,
    required this.numberValue,
  });

  @override
  int get progressId => numberValue;
}
