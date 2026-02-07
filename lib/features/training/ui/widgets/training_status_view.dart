import 'package:flutter/material.dart';

import '../../domain/training_state.dart';
import '../view_models/training_status_view_model.dart';

class TrainingStatusView extends StatelessWidget {
  const TrainingStatusView({
    super.key,
    required this.viewModel,
    required this.onRetry,
    required this.onContinue,
  });

  final TrainingStatusViewModel viewModel;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showMessage = viewModel.message.isNotEmpty;
    return Column(
      children: [
        if (showMessage)
          Text(
            viewModel.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        if (viewModel.hasError) ...[
          if (showMessage) const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              viewModel.errorMessage ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
        if (viewModel.sessionFinished) ...[
          if (showMessage || viewModel.hasError) const SizedBox(height: 16),
          _SessionSummaryCard(
            stats: viewModel.sessionStats!,
            onContinue: onContinue,
          ),
        ],
      ],
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.stats,
    required this.onContinue,
  });

  final SessionStats stats;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Session complete',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text('Cards completed: ${stats.cardsCompleted}', style: textStyle),
          Text('Duration: ${_formatDuration(stats.duration)}', style: textStyle),
          Text(
            'Recommended return: ${_formatTime(stats.recommendedReturn)}',
            style: textStyle,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onContinue,
            child: const Text('Continue session'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final paddedSeconds = seconds.toString().padLeft(2, '0');
    return '$minutes:$paddedSeconds';
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
