import '../learning_language.dart';
import '../time_value.dart';
import '../training_item.dart';
import '../training_task.dart';

class TimePronunciationTask extends TrainingTask implements PronunciationTaskData {
  final TimeValue timeValue;
  @override
  final String prompt;
  @override
  final LearningLanguage language;
  @override
  final List<String> answers;

  TimePronunciationTask({
    required super.id,
    required this.timeValue,
    required this.prompt,
    required this.language,
    required this.answers,
  }) : super(
         kind: TrainingTaskKind.numberPronunciation,
       );

  @override
  int? get numberValue => null;

  @override
  TrainingItemId get progressId => id;

  @override
  String get displayText => prompt;
}
