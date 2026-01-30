import 'package:flutter/material.dart';

import '../../domain/task_state.dart';
import 'training_feedback_view_model.dart';

class SpeechRecognitionLine {
  const SpeechRecognitionLine({
    required this.text,
    required this.isPreview,
  });

  final String text;
  final bool isPreview;
}

class NumberPronunciationViewModel {
  const NumberPronunciationViewModel({
    required this.title,
    required this.promptText,
    required this.expectedTokens,
    required this.matchedTokens,
    required this.previewMatchedIndices,
    required this.hintText,
    required this.feedbackText,
    required this.feedbackColor,
    required this.timer,
    required this.isTimerActive,
    required this.taskKey,
    required this.showSoundWave,
    required this.speechLines,
  });

  final String title;
  final String promptText;
  final List<String> expectedTokens;
  final List<bool> matchedTokens;
  final Set<int> previewMatchedIndices;
  final String? hintText;
  final String? feedbackText;
  final Color? feedbackColor;
  final TimerState timer;
  final bool isTimerActive;
  final String taskKey;
  final bool showSoundWave;
  final List<SpeechRecognitionLine> speechLines;

  bool get showHint => hintText != null && hintText!.isNotEmpty;
  bool get showFeedback => feedbackText != null;
  bool get showSpeechFeedback => speechLines.isNotEmpty;

  factory NumberPronunciationViewModel.fromState({
    required NumberPronunciationState? task,
    required TrainingFeedbackViewModel feedback,
  }) {
    final displayText = task?.displayText ?? '--';
    return NumberPronunciationViewModel(
      title: 'Read the number aloud',
      promptText: displayText.isEmpty ? '--' : displayText,
      expectedTokens: task?.expectedTokens ?? const <String>[],
      matchedTokens: task?.matchedTokens ?? const <bool>[],
      previewMatchedIndices:
          Set<int>.from(task?.previewMatchedIndices ?? const <int>[]),
      hintText: task?.hintText,
      feedbackText: feedback.text,
      feedbackColor: feedback.color,
      timer: task?.timer ?? TimerState.zero,
      isTimerActive: task?.timer.isRunning ?? false,
      taskKey: task?.taskId.storageKey ?? 'none',
      showSoundWave: task?.timer.isRunning ?? false,
      speechLines: _buildSpeechLines(task),
    );
  }

  static List<SpeechRecognitionLine> _buildSpeechLines(
    NumberPronunciationState? task,
  ) {
    if (task == null) {
      return const <SpeechRecognitionLine>[];
    }
    final expectedTokens = task.expectedTokens;
    final matchedIndices = task.lastMatchedIndices;
    final heardTokens = task.lastHeardTokens;
    final heardText = task.lastHeardText?.trim() ?? '';
    final heardDisplay =
        (heardTokens.isNotEmpty ? heardTokens.join(' ') : heardText).trim();
    final previewTokens = task.previewHeardTokens;
    final previewText = task.previewHeardText?.trim() ?? '';
    final previewDisplay =
        (previewTokens.isNotEmpty ? previewTokens.join(' ') : previewText)
            .trim();
    final previewIndices = task.previewMatchedIndices;

    final hasAny = heardDisplay.isNotEmpty ||
        matchedIndices.isNotEmpty ||
        previewDisplay.isNotEmpty ||
        previewIndices.isNotEmpty;
    if (!hasAny) {
      return const <SpeechRecognitionLine>[];
    }

    final matchedDisplay = _buildMatchedDisplay(expectedTokens, matchedIndices);
    final previewMatchedDisplay =
        _buildMatchedDisplay(expectedTokens, previewIndices);
    final lines = <SpeechRecognitionLine>[];
    if (previewDisplay.isNotEmpty) {
      lines.add(
        SpeechRecognitionLine(
          text: 'Listening: $previewDisplay',
          isPreview: true,
        ),
      );
    }
    if (previewIndices.isNotEmpty) {
      lines.add(
        SpeechRecognitionLine(
          text: 'Preview matched: $previewMatchedDisplay',
          isPreview: true,
        ),
      );
    }
    if (heardDisplay.isNotEmpty) {
      lines.add(
        SpeechRecognitionLine(
          text: 'Heard: $heardDisplay',
          isPreview: false,
        ),
      );
    }
    lines.add(
      SpeechRecognitionLine(
        text: 'Matched: $matchedDisplay',
        isPreview: false,
      ),
    );
    return List<SpeechRecognitionLine>.unmodifiable(lines);
  }

  static String _buildMatchedDisplay(
    List<String> expectedTokens,
    List<int> indices,
  ) {
    final matchedTokens = <String>[];
    for (final index in indices) {
      if (index >= 0 && index < expectedTokens.length) {
        matchedTokens.add(expectedTokens[index]);
      }
    }
    return matchedTokens.isEmpty ? '--' : matchedTokens.join(' ');
  }
}
