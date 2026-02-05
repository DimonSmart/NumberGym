import '../learning_language.dart';
import '../time_value.dart';
import '../training_item.dart';
import '../training_task.dart';
import 'number_to_word_task.dart';

class TimePronunciationTask extends TrainingTask
    with ValueToTextSpecBuilder
    implements PronunciationTaskData {
  @override
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

  @override
  String valueToTextPrompt(MultipleChoiceBuildContext context) =>
      timeValue.displayText;

  @override
  String valueToTextCorrectOption(MultipleChoiceBuildContext context) =>
      context.timeToWords(timeValue);

  @override
  List<String> valueToTextCandidateOptions(
    MultipleChoiceBuildContext context,
  ) {
    final candidates = <String>[];
    for (final candidate in _candidateTimeValues(context)) {
      if (candidate == timeValue) continue;
      candidates.add(context.timeToWords(candidate));
    }
    return candidates;
  }

  @override
  int? valueToTextMaxAttempts(int candidateCount) =>
      candidateCount * 3 + 5;

  List<TimeValue> _candidateTimeValues(MultipleChoiceBuildContext context) {
    final values = context.cardIds
        .where((itemId) => itemId.type == id.type && itemId.time != null)
        .map((itemId) => itemId.time!)
        .toList();
    if (values.isNotEmpty) return values;

    final generated = <TimeValue>{};
    while (generated.length < 24) {
      generated.add(
        TimeValue(
          hour: context.random.nextInt(24),
          minute: context.random.nextInt(60),
        ),
      );
    }
    return generated.toList();
  }
}
