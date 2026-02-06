import 'package:flutter/material.dart';

import '../../../data/card_progress.dart';
import '../../../../../core/theme/app_palette.dart';

class StatsColors {
  const StatsColors(this.scheme);

  final ColorScheme scheme;

  Color get notStarted => scheme.surfaceContainerHighest;

  Color get started => scheme.brightness == Brightness.dark
      ? Colors.amber.shade400
      : Colors.amber.shade200;

  Color get learned => AppPalette.deepBlue;

  Color progressColor(
    CardProgress progress,
    int streak,
    int learnedStreakTarget,
  ) {
    if (progress.totalAttempts == 0) return notStarted;
    if (progress.learned) return learned;

    if (streak <= 0) return started;
    final t = (streak / learnedStreakTarget).clamp(0.0, 1.0);
    return Color.lerp(started, learned, t)!;
  }
}
