import 'dart:math' as math;

import 'package:flutter/material.dart';

class SoundWaveform extends StatelessWidget {
  final List<double> values;
  final bool visible;
  final double height;
  final double barWidth;
  final double spacing;
  final Duration animationDuration;
  final double amplify;
  final double curve;

  const SoundWaveform({
    super.key,
    required this.values,
    required this.visible,
    this.height = 64,
    this.barWidth = 6,
    this.spacing = 2,
    this.animationDuration = const Duration(milliseconds: 90),
    this.amplify = 1.0,
    this.curve = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.onSurface.withValues(alpha: 0.82);
    final trackColor =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final barRadius = BorderRadius.circular(barWidth / 2);
    final minBarHeight = 8.0;

    return AnimatedOpacity(
      opacity: visible ? 1 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in values)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing),
                  child: AnimatedContainer(
                    duration: animationDuration,
                    width: barWidth,
                    height: _resolveHeight(
                      visible ? value : 0.0,
                      minBarHeight,
                    ),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: barRadius,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _resolveHeight(double value, double minBarHeight) {
    final boosted = (value * amplify).clamp(0.0, 1.0);
    final shaped = math.pow(boosted, curve).toDouble();
    return minBarHeight + shaped * (height - minBarHeight);
  }
}
