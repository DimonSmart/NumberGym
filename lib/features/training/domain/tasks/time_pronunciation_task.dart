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
  }) : super(kind: LearningMethod.numberPronunciation);

  factory TimePronunciationTask.forTime({
    required TrainingItemId id,
    required TimeValue timeValue,
    required LearningLanguage language,
    String Function(TimeValue time)? toWords,
  }) {
    final numeric = timeValue.displayText;
    final words = toWords?.call(timeValue) ?? numeric;
    final prompt = numeric;
    final answers = <String>[];
    void addAnswer(String text) {
      if (text.trim().isEmpty) return;
      if (answers.any((answer) => answer.toLowerCase() == text.toLowerCase())) {
        return;
      }
      answers.add(text);
    }

    addAnswer(prompt);
    addAnswer(words);
    addAnswer(numeric);
    return TimePronunciationTask(
      id: id,
      timeValue: timeValue,
      prompt: prompt,
      language: language,
      answers: answers,
    );
  }

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
  List<String> valueToTextCandidateOptions(MultipleChoiceBuildContext context) {
    final candidates = <String>[];
    for (final candidate in _candidateTimeValues(context)) {
      if (candidate == timeValue) continue;
      candidates.add(context.timeToWords(candidate));
    }
    return candidates;
  }

  @override
  int? valueToTextMaxAttempts(int candidateCount) => candidateCount * 3 + 5;

  List<TimeValue> _candidateTimeValues(MultipleChoiceBuildContext context) {
    final values = context.cardIds
        .where((itemId) => itemId.type == id.type && itemId.time != null)
        .map((itemId) => itemId.time!)
        .toList();
    if (values.isNotEmpty) return values;

    final hourOffset = context.random.nextInt(24);
    final minuteOffset = context.random.nextInt(60);
    return List<TimeValue>.generate(24, (index) {
      return TimeValue(
        hour: (hourOffset + index) % 24,
        minute: (minuteOffset + index * 13) % 60,
      );
    });
  }
}
