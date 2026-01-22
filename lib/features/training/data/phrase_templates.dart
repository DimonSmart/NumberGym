import 'dart:math';

import '../domain/learning_language.dart';
import '../domain/pronunciation_task.dart';

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

  PhrasePronunciationTask toTask({required int value, required int taskId}) {
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

class PhraseTemplates {
  PhraseTemplates(this.random);

  final Random random;

  List<PhraseTemplate> forLanguage(LearningLanguage language) {
    // Examples provided (kept as-is, Russian phrases).
    const common = <PhraseTemplate>[
      PhraseTemplate(
        id: 1,
        templateText: 'Моему дедушке {X} лет.',
        minValue: 40,
        maxValue: 100,
      ),
      PhraseTemplate(
        id: 2,
        templateText: 'Я пошел в магазин и купил {X} килограмм яблок.',
        minValue: 1,
        maxValue: 10,
      ),
    ];

    switch (language) {
      case LearningLanguage.english:
      case LearningLanguage.spanish:
        return common;
    }
  }

  PhraseTemplate? pick(LearningLanguage language, int value) {
    final available = forLanguage(language).where((t) => t.supports(value)).toList();
    if (available.isEmpty) return null;
    return available[random.nextInt(available.length)];
  }
}
