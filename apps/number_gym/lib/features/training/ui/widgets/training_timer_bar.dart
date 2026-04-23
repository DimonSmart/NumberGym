import 'package:flutter/material.dart';

class TrainingTimerBar extends StatelessWidget {
  const TrainingTimerBar({
    super.key,
    required this.duration,
    required this.remaining,
    required this.isActive,
    required this.taskKey,
  });

  final Duration duration;
  final Duration remaining;
  final bool isActive;
  final String taskKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = duration.inMilliseconds;
    final safeTotalMs = totalMs <= 0 ? 1 : totalMs;
    final clampedRemainingMs = remaining.inMilliseconds.clamp(0, safeTotalMs);
    final startValue = (clampedRemainingMs / safeTotalMs).clamp(0.0, 1.0);
    final pausedSeconds = (clampedRemainingMs / 1000).ceil();

    if (!isActive) {
      return _buildTimer(
        theme: theme,
        progress: startValue.toDouble(),
        secondsRemaining: pausedSeconds,
      );
    }

    final animationKey = ValueKey('$taskKey:$clampedRemainingMs:$isActive');
    return TweenAnimationBuilder<double>(
      key: animationKey,
      tween: Tween<double>(begin: startValue.toDouble(), end: 0.0),
      duration: Duration(milliseconds: clampedRemainingMs),
      builder: (context, value, child) {
        final secondsRemaining = ((safeTotalMs * value) / 1000).ceil();
        return _buildTimer(
          theme: theme,
          progress: value,
          secondsRemaining: secondsRemaining,
        );
      },
    );
  }

  Widget _buildTimer({
    required ThemeData theme,
    required double progress,
    required int secondsRemaining,
  }) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${secondsRemaining.clamp(0, 9999)}s',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
