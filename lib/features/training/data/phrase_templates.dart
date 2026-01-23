import 'dart:math';

import '../domain/learning_language.dart';
import '../domain/tasks/phrase_pronunciation_task.dart';

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
  switch (language) {
    case LearningLanguage.english:
      return const <PhraseTemplate>[
        PhraseTemplate(
          id: 1,
          templateText: 'My grandpa is {X} years old.',
          minValue: 40,
          maxValue: 100,
        ),
        PhraseTemplate(
          id: 2,
          templateText: 'My phone battery is at {X} percent.',
          minValue: 0,
          maxValue: 100,
        ),
        PhraseTemplate(
          id: 3,
          templateText: 'I bought {X} kilos of apples.',
          minValue: 1,
          maxValue: 10,
        ),
        PhraseTemplate(
          id: 4,
          templateText: 'The ticket costs {X} euros.',
          minValue: 0,
          maxValue: 1000,
        ),
        PhraseTemplate(
          id: 5,
          templateText: 'There are {X} people at the concert.',
          minValue: 0,
          maxValue: 10000,
        ),
      ];

    case LearningLanguage.spanish:
      return const <PhraseTemplate>[
        PhraseTemplate(
          id: 101,
          templateText: 'Mi abuelo tiene {X} años.',
          minValue: 40,
          maxValue: 100,
        ),
        PhraseTemplate(
          id: 102,
          templateText: 'La batería del móvil está al {X} por ciento.',
          minValue: 0,
          maxValue: 100,
        ),
        PhraseTemplate(
          id: 103,
          templateText: 'Compré {X} kilos de manzanas.',
          minValue: 1,
          maxValue: 10,
        ),
        PhraseTemplate(
          id: 104,
          templateText: 'La entrada cuesta {X} euros.',
          minValue: 0,
          maxValue: 1000,
        ),
        PhraseTemplate(
          id: 105,
          templateText: 'En el concierto hay {X} personas.',
          minValue: 0,
          maxValue: 10000,
        ),
      ];
   }
 }

  PhraseTemplate? pick(LearningLanguage language, int value) {
    final available = forLanguage(language).where((t) => t.supports(value)).toList();
    if (available.isEmpty) return null;
    return available[random.nextInt(available.length)];
  }
}
