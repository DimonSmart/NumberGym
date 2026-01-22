import 'training_task.dart';

/// Number-in-words multiple choice task (Stage 3).
class NumberReadingTask extends NumberTrainingTask {
  NumberReadingTask({
    required super.id,
    required super.numberValue,
    required this.prompt,
    required this.correctOption,
    required List<String> options,
  })  : options = List<String>.unmodifiable(options),
        super(kind: TrainingTaskKind.numberReading);

  final String prompt;
  final String correctOption;
  final List<String> options;

  @override
  String get displayText => prompt;
}

/// Total options shown in the number-reading mode (1 correct + rest incorrect).
const int numberReadingOptionCount = 3;
