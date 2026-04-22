import '../domain/tasks/phrase_pronunciation_task.dart';
import '../domain/training_item.dart';

class PhraseTemplate {
  final int id;
  final String templateText;
  final int minValue;
  final int maxValue;

  const PhraseTemplate({
    required this.id,
    required this.templateText,
    required this.minValue,
    required this.maxValue,
  });

  bool supports(int value) => value >= minValue && value <= maxValue;

  String materialize(int value) => templateText.replaceAll('{X}', value.toString());

  PhrasePronunciationTask toTask({
    required int value,
    required TrainingItemId taskId,
  }) {
    return PhrasePronunciationTask(
      id: taskId,
      phraseTemplateId: id,
      templateText: templateText,
      minValue: minValue,
      maxValue: maxValue,
      numberValue: value,
      text: materialize(value),
    );
  }
}
