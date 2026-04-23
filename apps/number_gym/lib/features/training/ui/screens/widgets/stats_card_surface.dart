import 'package:flutter/material.dart';

class StatsCardSurface extends StatelessWidget {
  const StatsCardSurface({
    super.key,
    this.width,
    this.accent,
    this.gradient,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    required this.child,
  });

  final double? width;
  final Color? accent;
  final Gradient? gradient;
  final EdgeInsets padding;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedGradient = gradient ??
        LinearGradient(
          colors: [
            scheme.surfaceContainerLow,
            (accent ?? scheme.primary).withValues(alpha: 0.12),
          ],
        );

    return SizedBox(
      width: width,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: resolvedGradient,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
