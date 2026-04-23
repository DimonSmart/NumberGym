import 'package:flutter/material.dart';

import '../../domain/task_state.dart';
import '../../domain/training_item.dart';
import 'training_feedback_view_model.dart';

class SpeechRecognitionLine {
  const SpeechRecognitionLine({required this.text, required this.isPreview});

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
    required this.heardDisplay,
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
  final String heardDisplay;
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
      title: _resolveTitle(task),
      promptText: displayText.isEmpty ? '--' : displayText,
      expectedTokens: task?.expectedTokens ?? const <String>[],
      matchedTokens: task?.matchedTokens ?? const <bool>[],
      previewMatchedIndices: Set<int>.from(
        task?.previewMatchedIndices ?? const <int>[],
      ),
      hintText: task?.hintText,
      feedbackText: feedback.text,
      feedbackColor: feedback.color,
      timer: task?.timer ?? TimerState.zero,
      isTimerActive: task?.timer.isRunning ?? false,
      taskKey: task?.taskId.storageKey ?? 'none',
      showSoundWave: task?.timer.isRunning ?? false,
      heardDisplay: _buildHeardDisplay(task),
      speechLines: _buildSpeechLines(task),
    );
  }

  static List<SpeechRecognitionLine> _buildSpeechLines(
    NumberPronunciationState? task,
  ) {
    if (task == null) {
      return const <SpeechRecognitionLine>[];
    }
    final previewTokens = task.previewHeardTokens;
    final previewText = task.previewHeardText?.trim() ?? '';
    final previewDisplay =
        (previewTokens.isNotEmpty ? previewTokens.join(' ') : previewText)
            .trim();
    if (previewDisplay.isEmpty) {
      return const <SpeechRecognitionLine>[];
    }

    final lines = <SpeechRecognitionLine>[];
    lines.add(
      SpeechRecognitionLine(
        text: 'Listening: $previewDisplay',
        isPreview: true,
      ),
    );
    return List<SpeechRecognitionLine>.unmodifiable(lines);
  }

  static String _buildHeardDisplay(NumberPronunciationState? task) {
    if (task == null) {
      return '';
    }
    final heardTokens = task.lastHeardTokens;
    final heardText = task.lastHeardText?.trim() ?? '';
    return (heardTokens.isNotEmpty ? heardTokens.join(' ') : heardText).trim();
  }

  static String _resolveTitle(NumberPronunciationState? task) {
    final itemType = task?.taskId.type;
    switch (itemType) {
      case TrainingItemType.timeExact:
      case TrainingItemType.timeQuarter:
      case TrainingItemType.timeHalf:
      case TrainingItemType.timeRandom:
        return 'Say the time aloud';
      case TrainingItemType.phone33x3:
      case TrainingItemType.phone3222:
      case TrainingItemType.phone2322:
        return 'Say the phone number aloud';
      case TrainingItemType.digits:
      case TrainingItemType.base:
      case TrainingItemType.hundreds:
      case TrainingItemType.thousands:
      case null:
        return 'Read the number aloud';
    }
  }
}
