import 'exercise_models.dart';

class TaskCardFlow {
  const TaskCardFlow();

  ExerciseCard resolveDynamicCard(ExerciseCard card) {
    return card.resolveDynamic();
  }

  String? resolveHintText({
    required ExerciseCard card,
    required ExerciseMode mode,
    required int consecutiveCorrect,
    required int hintVisibleUntilCorrectStreak,
  }) {
    if (mode != ExerciseMode.speak &&
        mode != ExerciseMode.reviewPronunciation) {
      return null;
    }
    if (hintVisibleUntilCorrectStreak <= 0 ||
        consecutiveCorrect >= hintVisibleUntilCorrectStreak) {
      return null;
    }
    if (card.acceptedAnswers.isEmpty) {
      return null;
    }

    final prompt = card.promptText.trim().toLowerCase();
    for (final answer in card.acceptedAnswers) {
      final trimmed = answer.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (prompt.isNotEmpty && trimmed.toLowerCase() == prompt) {
        continue;
      }
      return trimmed;
    }
    final fallback = card.acceptedAnswers.first.trim();
    return fallback.isEmpty ? null : fallback;
  }
}
