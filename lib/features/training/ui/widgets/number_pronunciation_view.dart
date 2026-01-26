import 'package:flutter/material.dart';

import '../view_models/number_pronunciation_view_model.dart';
import 'sound_wave_indicator.dart';
import 'training_timer_bar.dart';

class NumberPronunciationView extends StatelessWidget {
  const NumberPronunciationView({
    super.key,
    required this.viewModel,
    required this.soundStream,
  });

  final NumberPronunciationViewModel viewModel;
  final Stream<List<double>> soundStream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          viewModel.title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        _buildPrompt(theme, viewModel),
        if (viewModel.showHint) ...[
          const SizedBox(height: 6),
          Text(
            viewModel.hintText ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: viewModel.showFeedback ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            viewModel.feedbackText ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              color: viewModel.feedbackColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        TrainingTimerBar(
          duration: viewModel.timer.duration,
          isActive: viewModel.isTimerActive,
          taskKey: viewModel.taskKey,
        ),
        _buildSpeechRecognitionFeedback(theme, viewModel),
        SoundWaveIndicator(
          stream: soundStream,
          visible: viewModel.showSoundWave,
        ),
      ],
    );
  }

  Widget _buildPrompt(
    ThemeData theme,
    NumberPronunciationViewModel viewModel,
  ) {
    final prompt = viewModel.promptText.isEmpty ? '--' : viewModel.promptText;
    final baseStyle = theme.textTheme.displayLarge?.copyWith(
      fontSize: 86,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );

    if (viewModel.expectedTokens.isEmpty ||
        viewModel.matchedTokens.length != viewModel.expectedTokens.length ||
        baseStyle == null) {
      return Text(prompt, style: baseStyle, textAlign: TextAlign.center);
    }

    final matchedStyle = baseStyle.copyWith(color: theme.colorScheme.primary);
    final previewColor = theme.colorScheme.primary.withValues(alpha: 0.55);
    final previewStyle = baseStyle.copyWith(
      color: previewColor,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: previewColor,
    );
    final previewSet = viewModel.previewMatchedIndices;

    final spans = <TextSpan>[];
    for (var i = 0; i < viewModel.expectedTokens.length; i++) {
      final token = viewModel.expectedTokens[i];
      final isMatched = viewModel.matchedTokens[i];
      final isPreview = previewSet.contains(i);
      spans.add(
        TextSpan(
          text: token,
          style: isMatched
              ? matchedStyle
              : (isPreview ? previewStyle : baseStyle),
        ),
      );
      if (i < viewModel.expectedTokens.length - 1) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSpeechRecognitionFeedback(
    ThemeData theme,
    NumberPronunciationViewModel viewModel,
  ) {
    if (!viewModel.showSpeechFeedback) {
      return const SizedBox(height: 12);
    }

    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.2,
    );
    final previewStyle = style?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: viewModel.speechLines
            .map(
              (line) => Text(
                line.text,
                style: line.isPreview ? previewStyle : style,
                textAlign: TextAlign.center,
              ),
            )
            .toList(),
      ),
    );
  }
}
