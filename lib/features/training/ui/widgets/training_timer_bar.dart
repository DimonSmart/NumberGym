import 'package:flutter/material.dart';

class TrainingTimerBar extends StatelessWidget {
  const TrainingTimerBar({
    super.key,
    required this.duration,
    required this.isActive,
    required this.taskKey,
  });

  final Duration duration;
  final bool isActive;
  final String taskKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animationKey = ValueKey('$taskKey:$isActive');
    return TweenAnimationBuilder<double>(
      key: animationKey,
      tween: Tween<double>(begin: 1.0, end: 0.0),
      duration: isActive ? duration : Duration.zero,
      builder: (context, value, child) {
        final displayValue = isActive ? value : 0.0;
        final maxSeconds = duration.inSeconds;
        final secondsRemaining = isActive
            ? (maxSeconds * displayValue).ceil()
            : maxSeconds;

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: displayValue,
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${secondsRemaining}s',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
