import '../training_task.dart';

/// Text-to-value multiple choice task (Inverse Stage 3).
class TextToValueTask extends NumberTrainingTask {
  TextToValueTask({
    required super.id,
    required super.numberValue,
    required this.prompt,
    required this.correctOption,
    required List<String> options,
  })  : options = List<String>.unmodifiable(options),
        assert(id.number == numberValue),
        super(
          kind: LearningMethod.textToValue,
        );

  final String prompt;
  final String correctOption;
  final List<String> options;

  @override
  String get displayText => prompt;
}
