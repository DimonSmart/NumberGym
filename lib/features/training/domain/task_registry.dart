import 'dart:math';

import 'language_router.dart';
import 'learning_language.dart';
import 'task_runtime.dart';
import 'training_item.dart';
import 'training_services.dart';
import 'training_task.dart';
import 'tasks/number_pronunciation_task.dart';

class TaskBuildContext {
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

  final NumberPronunciationTask card;
  final LearningLanguage language;
  final List<TrainingItemId> cardIds;
  final String Function(int) toWords;
  final Duration cardDuration;
  final LanguageRouter languageRouter;
  final Random random;
  final TrainingServices services;
  final String? hintText;
}

typedef TaskFactory = TaskRuntime Function(TaskBuildContext context);

class TaskRegistry {
  TaskRegistry(this._factories);

  final Map<TrainingTaskKind, TaskFactory> _factories;

  TaskRuntime create(TrainingTaskKind kind, TaskBuildContext context) {
    final factory = _factories[kind];
    if (factory == null) {
      throw StateError('No task factory registered for $kind');
    }
    return factory(context);
  }
}
