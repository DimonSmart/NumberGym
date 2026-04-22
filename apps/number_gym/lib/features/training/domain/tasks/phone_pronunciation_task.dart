import '../learning_language.dart';
import '../time_value.dart';
import '../training_task.dart';

class PhonePronunciationTask extends TrainingTask
    implements PronunciationTaskData {
  @override
  final String prompt;
  @override
  final LearningLanguage language;
  @override
  final List<String> answers;
  final int _numberValue;

  PhonePronunciationTask({
    required super.id,
    required int numberValue,
    required this.prompt,
    required this.language,
    required this.answers,
  }) : _numberValue = numberValue,
       super(kind: LearningMethod.numberPronunciation);

  @override
  int? get numberValue => _numberValue;

  @override
  TimeValue? get timeValue => null;

  @override
  String get displayText => prompt;

  @override
  MultipleChoiceSpec buildValueToTextSpec(MultipleChoiceBuildContext context) {
    throw UnsupportedError(
      'Value-to-text tasks are not supported for phone numbers',
    );
  }
}
