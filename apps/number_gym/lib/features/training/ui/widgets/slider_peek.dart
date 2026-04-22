import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final RegExp _sliderAssetPattern = RegExp(
  r'^assets/images/sliders/(\d+)_.*\.(png|jpg|jpeg|webp)$',
  caseSensitive: false,
);

const Duration sliderPeekMoveDuration = Duration(milliseconds: 500);
const Duration sliderPeekHoldDuration = Duration(milliseconds: 500);

class SliderPeekAsset {
  const SliderPeekAsset({required this.assetPath, required this.clockPosition});

  final String assetPath;
  final int clockPosition;
}

class SliderPeekPlacement {
  const SliderPeekPlacement({
    required this.alignment,
    required this.hiddenOffset,
  });

  final Alignment alignment;
  final Offset hiddenOffset;
}

Future<List<SliderPeekAsset>> loadSliderPeekAssets({
  AssetBundle? assetBundle,
}) async {
  final bundle = assetBundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final parsed = <SliderPeekAsset>[];
  for (final asset in manifest.listAssets()) {
    final match = _sliderAssetPattern.firstMatch(asset);
    if (match == null) continue;
    final clockPosition = int.tryParse(match.group(1)!);
    if (clockPosition == null || clockPosition < 0 || clockPosition > 11) {
      continue;
    }
    parsed.add(SliderPeekAsset(assetPath: asset, clockPosition: clockPosition));
  }
  parsed.sort((a, b) => a.assetPath.compareTo(b.assetPath));
  return parsed;
}

SliderPeekAsset pickRandomSliderPeekAsset({
  required List<SliderPeekAsset> assets,
  required math.Random random,
}) {
  return assets[random.nextInt(assets.length)];
}

List<SliderPeekAsset> sliderPeekAssetsForClockPosition({
  required List<SliderPeekAsset> assets,
  required int clockPosition,
}) {
  return assets
      .where((asset) => asset.clockPosition == clockPosition)
      .toList(growable: false);
}

SliderPeekAsset? pickRandomSliderPeekAssetForClockPosition({
  required List<SliderPeekAsset> assets,
  required int clockPosition,
  required math.Random random,
}) {
  final matching = sliderPeekAssetsForClockPosition(
    assets: assets,
    clockPosition: clockPosition,
  );
  if (matching.isEmpty) {
    return null;
  }
  return matching[random.nextInt(matching.length)];
}

SliderPeekPlacement sliderPeekPlacementForClockPosition(int clockPosition) {
  switch (clockPosition) {
    case 0:
      return const SliderPeekPlacement(
        alignment: Alignment(0.0, -1.0),
        hiddenOffset: Offset(0.0, -1.0),
      );
    case 1:
      return const SliderPeekPlacement(
        alignment: Alignment(0.7, -1.0),
        hiddenOffset: Offset(0.0, -1.0),
      );
    case 2:
      return const SliderPeekPlacement(
        alignment: Alignment(1.0, -0.7),
        hiddenOffset: Offset(1.0, 0.0),
      );
    case 3:
      return const SliderPeekPlacement(
        alignment: Alignment(1.0, 0.0),
        hiddenOffset: Offset(1.0, 0.0),
      );
    case 4:
      return const SliderPeekPlacement(
        alignment: Alignment(1.0, 0.7),
        hiddenOffset: Offset(1.0, 0.0),
      );
    case 5:
      return const SliderPeekPlacement(
        alignment: Alignment(0.7, 1.0),
        hiddenOffset: Offset(0.0, 1.0),
      );
    case 6:
      return const SliderPeekPlacement(
        alignment: Alignment(0.0, 1.0),
        hiddenOffset: Offset(0.0, 1.0),
      );
    case 7:
      return const SliderPeekPlacement(
        alignment: Alignment(-0.7, 1.0),
        hiddenOffset: Offset(0.0, 1.0),
      );
    case 8:
      return const SliderPeekPlacement(
        alignment: Alignment(-1.0, 0.7),
        hiddenOffset: Offset(-1.0, 0.0),
      );
    case 9:
      return const SliderPeekPlacement(
        alignment: Alignment(-1.0, 0.0),
        hiddenOffset: Offset(-1.0, 0.0),
      );
    case 10:
      return const SliderPeekPlacement(
        alignment: Alignment(-1.0, -0.7),
        hiddenOffset: Offset(-1.0, 0.0),
      );
    case 11:
      return const SliderPeekPlacement(
        alignment: Alignment(-0.7, -1.0),
        hiddenOffset: Offset(0.0, -1.0),
      );
    default:
      return const SliderPeekPlacement(
        alignment: Alignment(0.0, -1.0),
        hiddenOffset: Offset(0.0, -1.0),
      );
  }
}

Animation<Offset> createSliderPeekAnimation({
  required AnimationController controller,
  required int clockPosition,
}) {
  final placement = sliderPeekPlacementForClockPosition(clockPosition);
  return Tween<Offset>(
    begin: placement.hiddenOffset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
}

Future<void> playSliderPeekSequence({
  required AnimationController controller,
  Duration holdDuration = sliderPeekHoldDuration,
  bool Function()? shouldContinue,
}) async {
  try {
    await controller.forward(from: 0);
    if (shouldContinue != null && !shouldContinue()) return;
    await Future<void>.delayed(holdDuration);
    if (shouldContinue != null && !shouldContinue()) return;
    await controller.reverse();
  } on TickerCanceled {
    // Controller was disposed while the sequence was running.
  }
}

Size resolveSliderPeekSize(BuildContext context) {
  final screen = MediaQuery.sizeOf(context);
  return Size(screen.width * 0.5, screen.height * 0.5);
}

class SliderPeekOverlay extends StatelessWidget {
  const SliderPeekOverlay({
    super.key,
    required this.assetPath,
    required this.clockPosition,
    required this.animation,
  });

  final String assetPath;
  final int clockPosition;
  final Animation<Offset> animation;

  @override
  Widget build(BuildContext context) {
    final placement = sliderPeekPlacementForClockPosition(clockPosition);
    final sliderSize = resolveSliderPeekSize(context);
    return IgnorePointer(
      child: Align(
        alignment: placement.alignment,
        child: SizedBox(
          width: sliderSize.width,
          height: sliderSize.height,
          child: SlideTransition(
            position: animation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(assetPath, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
