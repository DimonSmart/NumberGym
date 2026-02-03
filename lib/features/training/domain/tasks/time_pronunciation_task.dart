import '../learning_language.dart';
import '../time_value.dart';
import '../training_item.dart';
import '../training_task.dart';
import 'number_to_word_task.dart';

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

  @override
  MultipleChoiceSpec buildNumberToWordSpec(
    MultipleChoiceBuildContext context,
  ) {
    final value = timeValue;
    final correct = context.timeToWords(value);
    final options = <String>{correct};
    final candidateTimes = _candidateTimeValues(context);

    if (candidateTimes.isNotEmpty) {
      final maxAttempts = candidateTimes.length * 3 + 5;
      var attempts = 0;
      while (options.length < numberToWordOptionCount &&
          attempts < maxAttempts) {
        final candidate =
            candidateTimes[context.random.nextInt(candidateTimes.length)];
        attempts += 1;
        if (candidate == value) continue;
        options.add(context.timeToWords(candidate));
      }
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceSpec(
      prompt: value.displayText,
      correctOption: correct,
      options: shuffled,
      numberValue: null,
    );
  }

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
