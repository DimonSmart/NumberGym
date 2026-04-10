import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/ui/widgets/celebration_media_resolver.dart';

void main() {
  test('resolves image reward with direct sound using preferred extension', () {
    final selection = CelebrationMediaResolver.resolve(
      assets: const <String>[
        'assets/images/goal_rewards/1.png',
        'assets/audio/goal_rewards/1.ogg',
        'assets/audio/goal_rewards/1.mp3',
      ],
      counter: 1,
    );

    expect(selection, isNotNull);
    expect(selection!.kind, CelebrationMediaKind.image);
    expect(selection.mediaAsset, 'assets/images/goal_rewards/1.png');
    expect(selection.soundAsset, 'assets/audio/goal_rewards/1.mp3');
  });

  test('wraps counter and falls back to first available media slot', () {
    final selection = CelebrationMediaResolver.resolve(
      assets: const <String>[
        'assets/images/goal_rewards/1.png',
        'assets/audio/goal_rewards/2.wav',
      ],
      counter: 5,
    );

    expect(selection, isNotNull);
    expect(selection!.kind, CelebrationMediaKind.image);
    expect(selection.mediaAsset, 'assets/images/goal_rewards/1.png');
    expect(selection.soundAsset, 'assets/audio/goal_rewards/2.wav');
  });

  test('does not attach sound to video rewards', () {
    final selection = CelebrationMediaResolver.resolve(
      assets: const <String>[
        'assets/images/goal_rewards/3.mp4',
        'assets/audio/goal_rewards/3.mp3',
      ],
      counter: 3,
    );

    expect(selection, isNotNull);
    expect(selection!.kind, CelebrationMediaKind.video);
    expect(selection.mediaAsset, 'assets/images/goal_rewards/3.mp4');
    expect(selection.soundAsset, isNull);
  });
}
