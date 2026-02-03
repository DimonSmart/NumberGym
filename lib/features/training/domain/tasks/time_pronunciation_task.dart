import '../learning_language.dart';
import '../time_value.dart';
import '../training_task.dart';

class TimePronunciationTask extends TrainingTask {
  final TimeValue timeValue;
  final String prompt;
  final LearningLanguage language;
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
  String get displayText => timeValue.displayText;
}
