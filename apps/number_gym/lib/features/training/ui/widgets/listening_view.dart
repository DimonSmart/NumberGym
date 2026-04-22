import 'package:flutter/material.dart';

import '../view_models/listening_view_model.dart';
import 'training_timer_bar.dart';

class ListeningView extends StatelessWidget {
  const ListeningView({
    super.key,
    required this.viewModel,
    required this.onOptionSelected,
    required this.onReplay,
  });

  final ListeningViewModel viewModel;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onReplay;

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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: viewModel.showReplayHint ? onReplay : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  viewModel.displayText,
                  key: ValueKey(viewModel.displayText),
                  style: viewModel.promptStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        if (viewModel.showReplayHint) ...[
          const SizedBox(height: 4),
          Text(
            viewModel.replayHintText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: viewModel.options.map((option) {
            return SizedBox(
              width: viewModel.optionWidth,
              child: FilledButton.tonal(
                onPressed: () => onOptionSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      option,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          opacity: viewModel.showFeedback ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            viewModel.feedbackText ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              color: viewModel.feedbackColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        TrainingTimerBar(
          duration: viewModel.timer.duration,
          remaining: viewModel.timer.remaining,
          isActive: viewModel.isTimerActive,
          taskKey: viewModel.taskKey,
        ),
      ],
    );
  }
}
