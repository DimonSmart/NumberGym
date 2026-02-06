import '../learning_language.dart';
import '../time_value.dart';
import '../training_task.dart';
import 'number_to_word_task.dart';

class NumberPronunciationTask extends NumberTrainingTask
    with ValueToTextSpecBuilder
    implements PronunciationTaskData {
  @override
  final String prompt;
  @override
  final LearningLanguage language;
  @override
  final List<String> answers;

  NumberPronunciationTask({
    required super.id,
    required super.numberValue,
    required this.prompt,
    required this.language,
    required this.answers,
  })  : assert(id.number == numberValue),
        super(
          kind: LearningMethod.numberPronunciation,
        );

  @override
  String get displayText => prompt;

  @override
  TimeValue? get timeValue => null;

  @override
  int? get valueToTextNumberValue => numberValue;

  @override
  String valueToTextPrompt(MultipleChoiceBuildContext context) =>
      numberValue.toString();

  @override
  String valueToTextCorrectOption(MultipleChoiceBuildContext context) =>
      context.toWords(numberValue);

  @override
  List<String> valueToTextCandidateOptions(
    MultipleChoiceBuildContext context,
  ) {
    final candidates = <String>[];
    for (final itemId in context.cardIds) {
      if (itemId.type != id.type || itemId.number == null) continue;
      final candidateValue = itemId.number!;
      if (candidateValue == numberValue) continue;
      try {
        candidates.add(context.toWords(candidateValue));
      } catch (_) {
        // Skip invalid conversions and try another number.
      }
    }
    return candidates;
  }
}
