import 'package:flutter/material.dart';

class TrainingBackground extends StatelessWidget {
  final Widget child;
  static const String _backgroundAsset = 'assets/images/background.png';

  const TrainingBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            _backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
        child,
      ],
    );
  }
}
