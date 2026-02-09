import '../training_task.dart';

/// Shared builder for value-to-text multiple choice specs.
mixin ValueToTextSpecBuilder {
  int? get valueToTextNumberValue => null;
  String valueToTextPrompt(MultipleChoiceBuildContext context);
  String valueToTextCorrectOption(MultipleChoiceBuildContext context);
  List<String> valueToTextCandidateOptions(MultipleChoiceBuildContext context);

  int? valueToTextMaxAttempts(int candidateCount) => candidateCount * 3 + 5;

  MultipleChoiceSpec buildValueToTextSpec(MultipleChoiceBuildContext context) {
    final correct = valueToTextCorrectOption(context);
    final options = <String>{correct};
    final candidates = valueToTextCandidateOptions(context);

    if (candidates.isNotEmpty) {
      final maxAttempts = valueToTextMaxAttempts(candidates.length);
      var attempts = 0;
      while (options.length < valueToTextOptionCount) {
        if (maxAttempts != null && attempts >= maxAttempts) {
          break;
        }
        attempts += 1;
        final candidate = candidates[context.random.nextInt(candidates.length)];
        if (candidate.trim().isNotEmpty) {
          options.add(candidate);
        }
      }
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceSpec(
      prompt: valueToTextPrompt(context),
      correctOption: correct,
      options: shuffled,
      numberValue: valueToTextNumberValue,
    );
  }
}

/// Total options shown in multiple-choice tasks (1 correct + rest incorrect).
const int valueToTextOptionCount = 3;
