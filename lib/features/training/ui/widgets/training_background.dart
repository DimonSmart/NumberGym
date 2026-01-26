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
        Container(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage(_backgroundAsset),
              fit: BoxFit.cover,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
