class CelebrationMediaResolver {
  static final RegExp _mediaPattern = RegExp(
    r'^assets/images/goal_rewards/(\d+)\.(png|mp4)$',
    caseSensitive: false,
  );
  static final RegExp _soundPattern = RegExp(
    r'^assets/audio/goal_rewards/(\d+)\.(mp3|wav|ogg|m4a|aac)$',
    caseSensitive: false,
  );
  static const List<String> _soundPriority = <String>[
    'mp3',
    'wav',
    'ogg',
    'm4a',
    'aac',
  ];

  const CelebrationMediaResolver._();

  static CelebrationMediaSelection? resolve({
    required Iterable<String> assets,
    required int counter,
  }) {
    final mediaByNumber = <int, _IndexedMedia>{};
    final soundsByNumber = <int, Map<String, String>>{};

    for (final asset in assets) {
      final mediaMatch = _mediaPattern.firstMatch(asset);
      if (mediaMatch != null) {
        final number = int.tryParse(mediaMatch.group(1)!);
        final extension = mediaMatch.group(2)!.toLowerCase();
        if (number == null) {
          continue;
        }
        final media = mediaByNumber.putIfAbsent(number, _IndexedMedia.new);
        if (extension == 'png') {
          media.imageAsset = asset;
        } else if (extension == 'mp4') {
          media.videoAsset = asset;
        }
        continue;
      }

      final soundMatch = _soundPattern.firstMatch(asset);
      if (soundMatch == null) {
        continue;
      }
      final number = int.tryParse(soundMatch.group(1)!);
      final extension = soundMatch.group(2)!.toLowerCase();
      if (number == null) {
        continue;
      }
      final sounds = soundsByNumber.putIfAbsent(
        number,
        () => <String, String>{},
      );
      sounds.putIfAbsent(extension, () => asset);
    }

    if (mediaByNumber.isEmpty) {
      return null;
    }

    final orderedNumbers = mediaByNumber.keys.toList()..sort();
    final normalizedCounter = counter <= 0 ? 1 : counter;
    final index = (normalizedCounter - 1) % orderedNumbers.length;
    var selectedNumber = orderedNumbers[index];
    var selectedMedia = mediaByNumber[selectedNumber];

    if (selectedMedia == null || !selectedMedia.hasMedia) {
      for (final number in orderedNumbers) {
        final fallback = mediaByNumber[number];
        if (fallback != null && fallback.hasMedia) {
          selectedNumber = number;
          selectedMedia = fallback;
          break;
        }
      }
    }

    if (selectedMedia == null || !selectedMedia.hasMedia) {
      return null;
    }

    final mediaAsset = selectedMedia.imageAsset ?? selectedMedia.videoAsset;
    if (mediaAsset == null) {
      return null;
    }

    final kind = selectedMedia.imageAsset != null
        ? CelebrationMediaKind.image
        : CelebrationMediaKind.video;
    final soundAsset = kind == CelebrationMediaKind.video
        ? null
        : _resolveSoundAsset(
            soundsByNumber: soundsByNumber,
            mediaNumber: selectedNumber,
            counter: normalizedCounter,
          );

    return CelebrationMediaSelection(
      kind: kind,
      mediaAsset: mediaAsset,
      soundAsset: soundAsset,
    );
  }

  static String? _resolveSoundAsset({
    required Map<int, Map<String, String>> soundsByNumber,
    required int mediaNumber,
    required int counter,
  }) {
    final direct = soundsByNumber[mediaNumber];
    final directAsset = _pickByPriority(direct);
    if (directAsset != null) {
      return directAsset;
    }

    if (soundsByNumber.isEmpty) {
      return null;
    }

    final orderedNumbers = soundsByNumber.keys.toList()..sort();
    final index = (counter - 1) % orderedNumbers.length;
    final fallback = soundsByNumber[orderedNumbers[index]];
    return _pickByPriority(fallback);
  }

  static String? _pickByPriority(Map<String, String>? byExtension) {
    if (byExtension == null || byExtension.isEmpty) {
      return null;
    }
    for (final extension in _soundPriority) {
      final candidate = byExtension[extension];
      if (candidate != null) {
        return candidate;
      }
    }
    return byExtension.values.first;
  }
}

class CelebrationMediaSelection {
  const CelebrationMediaSelection({
    required this.kind,
    required this.mediaAsset,
    required this.soundAsset,
  });

  final CelebrationMediaKind kind;
  final String mediaAsset;
  final String? soundAsset;
}

enum CelebrationMediaKind { image, video }

class _IndexedMedia {
  String? imageAsset;
  String? videoAsset;

  bool get hasMedia => imageAsset != null || videoAsset != null;
}
