import '../training_task.dart';

/// Word-to-number multiple choice task (Inverse Stage 3).
class WordToNumberTask extends NumberTrainingTask {
  WordToNumberTask({
    required super.id,
    required super.numberValue,
    required this.prompt,
    required this.correctOption,
    required List<String> options,
  })  : options = List<String>.unmodifiable(options),
        assert(id.number == numberValue),
        super(
          kind: TrainingTaskKind.wordToNumber,
        );

  final String prompt;
  final String correctOption;
  final List<String> options;

  @override
  String get displayText => prompt;
}
