import 'package:flutter/material.dart';

import 'sound_waveform.dart';

class SoundWaveIndicator extends StatelessWidget {
  final Stream<List<double>> stream;
  final bool visible;
  final double height;
  final double barWidth;
  final double spacing;
  final Duration animationDuration;
  final double amplify;
  final double curve;

  const SoundWaveIndicator({
    super.key,
    required this.stream,
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
    return StreamBuilder<List<double>>(
      stream: stream,
      initialData: const [],
      builder: (context, snapshot) {
        return SoundWaveform(
          values: snapshot.data ?? const [],
          visible: visible,
          height: height,
          barWidth: barWidth,
          spacing: spacing,
          animationDuration: animationDuration,
          amplify: amplify,
          curve: curve,
        );
      },
    );
  }
}
