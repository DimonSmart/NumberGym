import 'dart:math' as math;

import 'package:flutter/material.dart';

class SoundWaveform extends StatelessWidget {
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

  final List<double> values;
  final bool visible;
  final double height;
  final double barWidth;
  final double spacing;
  final int barCount;
  final Duration animationDuration;
  final double amplify;
  final double curve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.onSurface.withValues(alpha: 0.82);
    final trackColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.7,
    );
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);
    final centerLineColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barLayout = _resolveBarLayout(
                maxWidth: constraints.maxWidth,
                barCount: resolvedValues.length,
              );
              final barRadius = BorderRadius.circular(barLayout.barWidth / 2);

              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(height: 1, color: centerLineColor),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < resolvedValues.length; i += 1) ...[
                        SizedBox(
                          height: height,
                          child: Align(
                            alignment: Alignment.center,
                            child: AnimatedContainer(
                              duration: animationDuration,
                              width: barLayout.barWidth,
                              height: _resolveHeight(
                                visible ? resolvedValues[i] : 0.0,
                                minBarHeight,
                              ),
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: barRadius,
                              ),
                            ),
                          ),
                        ),
                        if (i < resolvedValues.length - 1)
                          SizedBox(width: barLayout.spacing),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  _BarLayout _resolveBarLayout({
    required double maxWidth,
    required int barCount,
  }) {
    if (barCount <= 0 || maxWidth <= 0 || maxWidth.isInfinite) {
      return _BarLayout(barWidth: barWidth, spacing: spacing);
    }

    final gapCount = barCount - 1;
    final preferredWidth = barCount * barWidth + gapCount * spacing;
    if (preferredWidth <= maxWidth) {
      return _BarLayout(barWidth: barWidth, spacing: spacing);
    }

    if (gapCount > 0) {
      final spacingThatFits = (maxWidth - barCount * barWidth) / gapCount;
      if (spacingThatFits >= 0) {
        return _BarLayout(barWidth: barWidth, spacing: spacingThatFits);
      }
    }

    return _BarLayout(barWidth: maxWidth / barCount, spacing: 0);
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

class _BarLayout {
  const _BarLayout({required this.barWidth, required this.spacing});

  final double barWidth;
  final double spacing;
}
