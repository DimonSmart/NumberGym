import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/pronunciation_models.dart';
import '../view_models/phrase_pronunciation_view_model.dart';
import 'sound_wave_indicator.dart';

class PhrasePronunciationView extends StatelessWidget {
  const PhrasePronunciationView({
    super.key,
    required this.viewModel,
    required this.soundStream,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onRecordAgain,
    required this.onSendRecording,
    required this.onCompleteReview,
  });

  final PhrasePronunciationViewModel viewModel;
  final Stream<List<double>> soundStream;
  final Future<void> Function() onStartRecording;
  final Future<void> Function() onStopRecording;
  final Future<void> Function() onRecordAgain;
  final Future<void> Function() onSendRecording;
  final Future<void> Function() onCompleteReview;

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
        ),
        const SizedBox(height: 10),
        _buildPronunciationPhrase(theme, viewModel.displayText, viewModel.result),
        if (viewModel.result != null) ...[
          const SizedBox(height: 12),
          _buildPronunciationSummary(theme, viewModel.result!),
        ],
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            if (viewModel.showRecordButton)
              FilledButton.icon(
                onPressed: () async => onStartRecording(),
                icon: const Icon(Icons.mic),
                label: const Text('Record'),
              ),
            if (viewModel.showStopButton)
              FilledButton.icon(
                onPressed: () async => onStopRecording(),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
              ),
            if (viewModel.showRecordAgainButton)
              FilledButton.tonalIcon(
                onPressed: () async => onRecordAgain(),
                icon: const Icon(Icons.mic_none),
                label: const Text('Record again'),
              ),
            if (viewModel.showSendButton)
              FilledButton.icon(
                onPressed: viewModel.disableSend
                    ? null
                    : () async => onSendRecording(),
                icon: viewModel.showSendProgress
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(viewModel.sendLabel),
              ),
            if (viewModel.showNextButton)
              FilledButton.icon(
                onPressed: () async => onCompleteReview(),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          viewModel.helperText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SoundWaveIndicator(
          stream: soundStream,
          visible: viewModel.isWaveVisible,
        ),
      ],
    );
  }

  Widget _buildPronunciationPhrase(
    ThemeData theme,
    String displayText,
    PronunciationAnalysisResult? result,
  ) {
    final baseStyle =
        theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700) ??
            const TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
    final resolvedText = (result?.displayText?.trim().isNotEmpty ?? false)
        ? result!.displayText!.trim()
        : displayText;
    final best = result?.best;

    if (best == null || best.words.isEmpty) {
      return Text(resolvedText, style: baseStyle, textAlign: TextAlign.center);
    }

    final tokens = _tokenizePhrase(resolvedText);
    final spans = <InlineSpan>[];
    var wordIndex = 0;

    for (final token in tokens) {
      if (!token.isWord) {
        spans.add(TextSpan(text: token.text, style: baseStyle));
        continue;
      }
      if (wordIndex >= best.words.length) {
        spans.add(TextSpan(text: token.text, style: baseStyle));
        continue;
      }
      final word = best.words[wordIndex];
      wordIndex += 1;
      final color = _wordScoreColor(theme, word.accuracyScore);
      final tooltip = _buildWordTooltip(word);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Tooltip(
            message: tooltip,
            triggerMode: TooltipTriggerMode.tap,
            decoration: BoxDecoration(
              color: theme.colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: color, width: 2)),
              ),
              child: Text(token.text, style: baseStyle.copyWith(color: color)),
            ),
          ),
        ),
      );
    }

    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
  }

  Widget _buildPronunciationSummary(
    ThemeData theme,
    PronunciationAnalysisResult result,
  ) {
    final best = result.best;
    if (best == null) {
      return const SizedBox.shrink();
    }
    final recommendation = _extractRecommendation(result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPronunciationLegend(theme),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildScoreIndicator(
                theme,
                label: 'Accuracy',
                score: best.accuracyScore,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildScoreIndicator(
                theme,
                label: 'Fluency',
                score: best.fluencyScore,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildScoreIndicator(
                theme,
                label: 'Completeness',
                score: best.completenessScore,
              ),
            ),
          ],
        ),
        if (recommendation != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              recommendation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPronunciationLegend(ThemeData theme) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(color: Colors.green.shade600, label: 'Correct'),
        const _LegendItem(color: AppPalette.warmOrange, label: 'Almost'),
        _LegendItem(color: theme.colorScheme.error, label: 'Wrong'),
      ],
    );
  }

  Widget _buildScoreIndicator(
    ThemeData theme, {
    required String label,
    required double score,
  }) {
    final normalized = (score / 100).clamp(0.0, 1.0);
    final color = _wordScoreColor(theme, score);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score.toStringAsFixed(0),
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Color _wordScoreColor(ThemeData theme, double score) {
    if (score >= 80) {
      return Colors.green.shade600;
    }
    if (score >= 60) {
      return AppPalette.warmOrange;
    }
    return theme.colorScheme.error;
  }

  String _buildWordTooltip(PronunciationWord word) {
    final buffer = StringBuffer();
    buffer.writeln(word.word);
    buffer.writeln('Accuracy: ${word.accuracyScore.toStringAsFixed(0)}');
    final error = word.errorType?.trim();
    if (error != null && error.isNotEmpty && error.toLowerCase() != 'none') {
      buffer.writeln('Error: $error');
    }
    if (word.phonemes.isNotEmpty) {
      final phonemes = word.phonemes
          .take(6)
          .map(
            (phoneme) =>
                '${phoneme.phoneme} ${phoneme.accuracyScore.toStringAsFixed(0)}',
          )
          .join(', ');
      buffer.writeln('Phonemes: $phonemes');
    }
    return buffer.toString().trim();
  }

  String? _extractRecommendation(PronunciationAnalysisResult result) {
    final raw = result.rawJson;
    if (raw == null) return null;
    const keys = {
      'recommendation',
      'recommendations',
      'suggestion',
      'suggestions',
      'feedback',
      'advice',
      'note',
      'notes',
      'message',
      'comment',
      'comments',
      'hint',
      'hints',
    };
    final found = _findFirstStringByKey(raw, keys, 0);
    if (found == null) return null;
    final trimmed = found.trim();
    if (trimmed.isEmpty) return null;
    const maxLength = 420;
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }

  String? _findFirstStringByKey(dynamic node, Set<String> keys, int depth) {
    if (node == null || depth > 6) return null;
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        final value = entry.value;
        if (keys.contains(key) && value is String && value.trim().isNotEmpty) {
          return value;
        }
        final nested = _findFirstStringByKey(value, keys, depth + 1);
        if (nested != null) return nested;
      }
    } else if (node is List) {
      for (final item in node) {
        final nested = _findFirstStringByKey(item, keys, depth + 1);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  List<_PhraseToken> _tokenizePhrase(String text) {
    final tokenRegex = RegExp(
      r"[\\p{L}\\p{N}']+|[^\\p{L}\\p{N}']+",
      unicode: true,
    );
    final wordRegex = RegExp(r"^[\\p{L}\\p{N}']+$", unicode: true);
    return tokenRegex.allMatches(text).map((match) {
      final token = match.group(0) ?? '';
      return _PhraseToken(token, wordRegex.hasMatch(token));
    }).toList();
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PhraseToken {
  final String text;
  final bool isWord;

  const _PhraseToken(this.text, this.isWord);
}
