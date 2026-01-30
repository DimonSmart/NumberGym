import '../training_task.dart';

/// Number-to-word multiple choice task (Stage 3).
class NumberToWordTask extends NumberTrainingTask {
  NumberToWordTask({
    required super.id,
    required super.numberValue,
    required this.prompt,
    required this.correctOption,
    required List<String> options,
  })  : options = List<String>.unmodifiable(options),
        assert(id.number == numberValue),
        super(
          kind: TrainingTaskKind.numberToWord,
        );

  final String prompt;
  final String correctOption;
  final List<String> options;

  @override
  String get displayText => prompt;
}

/// Total options shown in the number-reading mode (1 correct + rest incorrect).
const int numberToWordOptionCount = 3;
