import 'package:flutter/material.dart';

class TrainingBackground extends StatelessWidget {
  final Widget child;

  const TrainingBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface,
                scheme.primaryContainer.withValues(alpha: 0.35),
              ],
            ),
          ),
        ),
        Positioned(
          top: -60,
          left: -30,
          child: _bubble(
            170,
            scheme.secondaryContainer.withValues(alpha: 0.3),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -40,
          child: _bubble(
            200,
            scheme.tertiaryContainer.withValues(alpha: 0.25),
          ),
        ),
        Positioned(
          top: 160,
          right: -30,
          child: _bubble(
            110,
            scheme.primary.withValues(alpha: 0.12),
          ),
        ),
        child,
      ],
    );
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
