import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/ui/widgets/slider_peek.dart';

void main() {
  const assets = <SliderPeekAsset>[
    SliderPeekAsset(
      assetPath: 'assets/images/sliders/3_first.png',
      clockPosition: 3,
    ),
    SliderPeekAsset(
      assetPath: 'assets/images/sliders/3_second.png',
      clockPosition: 3,
    ),
    SliderPeekAsset(
      assetPath: 'assets/images/sliders/9_only.png',
      clockPosition: 9,
    ),
  ];

  test('returns only assets for selected clock position', () {
    final matching = sliderPeekAssetsForClockPosition(
      assets: assets,
      clockPosition: 3,
    );

    expect(matching, hasLength(2));
    expect(matching.every((asset) => asset.clockPosition == 3), isTrue);
    expect(
      matching.map((asset) => asset.assetPath),
      containsAllInOrder(<String>[
        'assets/images/sliders/3_first.png',
        'assets/images/sliders/3_second.png',
      ]),
    );
  });

  test('returns null when no assets exist for selected clock position', () {
    final picked = pickRandomSliderPeekAssetForClockPosition(
      assets: assets,
      clockPosition: 0,
      random: math.Random(1),
    );

    expect(picked, isNull);
  });

  test('never picks asset from another clock position', () {
    final random = math.Random(7);
    for (var i = 0; i < 25; i++) {
      final picked = pickRandomSliderPeekAssetForClockPosition(
        assets: assets,
        clockPosition: 3,
        random: random,
      );
      expect(picked, isNotNull);
      expect(picked!.clockPosition, 3);
    }
  });
}
