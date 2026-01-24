import 'dart:math' as math;

import 'package:flutter/material.dart';

class SoundWaveform extends StatelessWidget {
  final List<double> values;
  final bool visible;
  final double height;
  final double barWidth;
  final double spacing;
  final int barCount;
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
    this.barCount = 32,
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
    final centerLineColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final barRadius = BorderRadius.circular(barWidth / 2);
    final minBarHeight = 8.0;
    final resolvedValues = _resolveValues();

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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 1,
                    color: centerLineColor,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final value in resolvedValues)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: spacing),
                      child: SizedBox(
                        height: height,
                        child: Align(
                          alignment: Alignment.center,
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
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<double> _resolveValues() {
    if (barCount <= 0) {
      return const [];
    }
    if (values.length == barCount) {
      return values;
    }
    if (values.isEmpty) {
      return List<double>.filled(barCount, 0.0);
    }
    if (values.length > barCount) {
      return values.sublist(values.length - barCount);
    }
    final padded = List<double>.filled(barCount, 0.0);
    final startIndex = barCount - values.length;
    for (var i = 0; i < values.length; i++) {
      padded[startIndex + i] = values[i];
    }
    return padded;
  }

  double _resolveHeight(double value, double minBarHeight) {
    final boosted = (value * amplify).clamp(0.0, 1.0);
    final shaped = math.pow(boosted, curve).toDouble();
    return minBarHeight + shaped * (height - minBarHeight);
  }
}
