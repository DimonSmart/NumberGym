import '../training_task.dart';

class PhrasePronunciationTask extends NumberTrainingTask {
  final int phraseTemplateId;
  final String templateText;
  final int minValue;
  final int maxValue;
  final String text;

  PhrasePronunciationTask({
    required super.id,
    required this.phraseTemplateId,
    required this.templateText,
    required this.minValue,
    required this.maxValue,
    required super.numberValue,
    required this.text,
  }) : assert(id.number == numberValue),
       super(kind: LearningMethod.phrasePronunciation);

  @override
  String get displayText => text;
}
