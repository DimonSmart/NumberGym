import 'dart:math';

import 'language_router.dart';
import 'learning_language.dart';
import 'task_runtime.dart';
import 'training_item.dart';
import 'training_services.dart';
import 'training_task.dart';
import 'time_value.dart';

class TaskBuildContext implements MultipleChoiceBuildContext {
  TaskBuildContext({
    required this.card,
    required this.language,
    required this.cardIds,
    required this.toWords,
    required this.cardDuration,
    required this.languageRouter,
    required this.random,
    required this.services,
    required this.hintText,
  });

  final PronunciationTaskData card;
  @override
  final LearningLanguage language;
  @override
  final List<TrainingItemId> cardIds;
  @override
  final String Function(int) toWords;
  final Duration cardDuration;
  final LanguageRouter languageRouter;
  @override
  final Random random;
  final TrainingServices services;
  final String? hintText;

  @override
  String Function(TimeValue) get timeToWords =>
      (value) => languageRouter.timeToWords(value, language: language);
}

typedef TaskFactory = TaskRuntime Function(TaskBuildContext context);

class TaskRegistry {
  TaskRegistry(this._factories);

  final Map<LearningMethod, TaskFactory> _factories;

  TaskRuntime create(LearningMethod kind, TaskBuildContext context) {
    final factory = _factories[kind];
    if (factory == null) {
      throw StateError('No task factory registered for $kind');
    }
    return factory(context);
  }
}
