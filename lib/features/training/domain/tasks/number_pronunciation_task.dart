import '../learning_language.dart';
import '../time_value.dart';
import '../training_task.dart';
import 'number_to_word_task.dart';

class NumberPronunciationTask extends NumberTrainingTask
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
          kind: TrainingTaskKind.numberPronunciation,
        );

  @override
  String get displayText => prompt;

  @override
  TimeValue? get timeValue => null;

  @override
  MultipleChoiceSpec buildNumberToWordSpec(
    MultipleChoiceBuildContext context,
  ) {
    final value = numberValue;
    final correct = context.toWords(value);
    final options = <String>{correct};
    final candidateIds = context.cardIds
        .where((itemId) => itemId.type == id.type && itemId.number != null)
        .toList();

    if (candidateIds.isNotEmpty) {
      while (options.length < numberToWordOptionCount) {
        final candidateId =
            candidateIds[context.random.nextInt(candidateIds.length)];
        final candidateValue = candidateId.number!;
        if (candidateValue == value) continue;
        try {
          options.add(context.toWords(candidateValue));
        } catch (_) {
          // Skip invalid conversions and try another number.
        }
      }
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceSpec(
      prompt: value.toString(),
      correctOption: correct,
      options: shuffled,
      numberValue: value,
    );
  }
}
