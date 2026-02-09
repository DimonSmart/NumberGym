import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../domain/training_state.dart';

class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.celebration,
    required this.onContinue,
  });

  final TrainingCelebration celebration;
  final VoidCallback onContinue;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
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

  _CelebrationMediaSelection? _selection;
  Object? _loadError;
  bool _loading = true;
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareMedia());
  }

  @override
  void didUpdateWidget(covariant CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.celebration.eventId != widget.celebration.eventId) {
      unawaited(_prepareMedia());
    }
  }

  @override
  void dispose() {
    unawaited(_disposePlayback());
    super.dispose();
  }

  Future<void> _prepareMedia() async {
    await _disposePlayback();
    if (!mounted) return;

    setState(() {
      _loading = true;
      _selection = null;
      _loadError = null;
    });

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final selection = _resolveSelection(
        assets: manifest.listAssets(),
        counter: widget.celebration.counter,
      );
      if (!mounted) return;

      if (selection != null) {
        if (selection.kind == _CelebrationMediaKind.video) {
          final controller = VideoPlayerController.asset(selection.mediaAsset);
          _videoController = controller;
          await controller.initialize();
          if (!mounted || _videoController != controller) {
            await controller.dispose();
            return;
          }
          await controller.play();
        } else if (selection.soundAsset != null) {
          final player = _audioPlayer ??= AudioPlayer();
          await player.stop();
          await player.play(
            AssetSource(_assetSourcePath(selection.soundAsset!)),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _selection = selection;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _disposePlayback() async {
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      await controller.dispose();
    }

    final player = _audioPlayer;
    _audioPlayer = null;
    if (player != null) {
      await player.stop();
      await player.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaSize = _resolveMediaSize(context);
    final hasConcreteMasteredValue = _hasConcreteMasteredValue();
    final primaryMasteredText = _resolvePrimaryMasteredText();
    final categoryLabel = widget.celebration.categoryLabel.trim();
    return ColoredBox(
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Milestone reached',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'You mastered',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          primaryMasteredText,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (hasConcreteMasteredValue &&
                          categoryLabel.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                categoryLabel,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildSummaryCard(theme),
                      const SizedBox(height: 18),
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: mediaSize,
                            maxHeight: mediaSize,
                          ),
                          child: _buildMediaContent(theme),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: widget.onContinue,
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final celebration = widget.celebration;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryLine(theme, 'Method', celebration.learningMethodLabel),
            _buildSummaryLine(
              theme,
              'Session progress',
              _sessionProgressText(),
            ),
            _buildSummaryLine(theme, 'Today progress', _todayProgressText()),
            _buildSummaryLine(
              theme,
              'Total mastered',
              '${celebration.cardsLearnedTotal} cards',
            ),
            _buildSummaryLine(
              theme,
              'Remaining',
              '${celebration.cardsRemainingTotal} cards',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(ThemeData theme, String label, String value) {
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: labelStyle),
            TextSpan(text: value, style: valueStyle),
          ],
        ),
      ),
    );
  }

  bool _hasConcreteMasteredValue() {
    return widget.celebration.masteredText.trim().isNotEmpty;
  }

  String _resolvePrimaryMasteredText() {
    final masteredText = widget.celebration.masteredText.trim();
    if (masteredText.isNotEmpty) {
      return masteredText;
    }

    final category = widget.celebration.categoryLabel.trim();
    if (category.isNotEmpty) {
      return category;
    }

    return 'New card';
  }

  String _sessionProgressText() {
    final celebration = widget.celebration;
    final target = celebration.sessionTargetCards <= 0
        ? celebration.sessionCardsCompleted
        : celebration.sessionTargetCards;
    return '${celebration.sessionCardsCompleted}/$target cards';
  }

  String _todayProgressText() {
    final celebration = widget.celebration;
    final target = celebration.cardsTargetToday <= 0
        ? celebration.cardsCompletedToday
        : celebration.cardsTargetToday;
    return '${celebration.cardsCompletedToday}/$target attempts';
  }

  Widget _buildMediaContent(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selection == null) {
      return _buildFallback(
        theme: theme,
        text: _loadError == null
            ? 'Add reward media files to assets/images/goal_rewards/'
            : 'Failed to load reward media',
      );
    }

    if (_selection!.kind == _CelebrationMediaKind.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(_selection!.mediaAsset, fit: BoxFit.contain),
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspectRatio = controller.value.aspectRatio <= 0
        ? 1.0
        : controller.value.aspectRatio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildFallback({required ThemeData theme, required String text}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            text,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  double _resolveMediaSize(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final candidate = shortest * 0.9;
    return candidate.clamp(260.0, 560.0).toDouble();
  }

  _CelebrationMediaSelection? _resolveSelection({
    required List<String> assets,
    required int counter,
  }) {
    final mediaByNumber = <int, _IndexedMedia>{};
    final soundsByNumber = <int, Map<String, String>>{};

    for (final asset in assets) {
      final mediaMatch = _mediaPattern.firstMatch(asset);
      if (mediaMatch != null) {
        final number = int.tryParse(mediaMatch.group(1)!);
        final extension = mediaMatch.group(2)!.toLowerCase();
        if (number == null) continue;
        final media = mediaByNumber.putIfAbsent(number, _IndexedMedia.new);
        if (extension == 'png') {
          media.imageAsset = asset;
        } else if (extension == 'mp4') {
          media.videoAsset = asset;
        }
        continue;
      }

      final soundMatch = _soundPattern.firstMatch(asset);
      if (soundMatch == null) continue;
      final number = int.tryParse(soundMatch.group(1)!);
      final extension = soundMatch.group(2)!.toLowerCase();
      if (number == null) continue;
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
        ? _CelebrationMediaKind.image
        : _CelebrationMediaKind.video;
    final soundAsset = kind == _CelebrationMediaKind.video
        ? null
        : _resolveSoundAsset(
            soundsByNumber: soundsByNumber,
            mediaNumber: selectedNumber,
            counter: normalizedCounter,
          );

    return _CelebrationMediaSelection(
      kind: kind,
      mediaAsset: mediaAsset,
      soundAsset: soundAsset,
    );
  }

  String? _resolveSoundAsset({
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

  String? _pickByPriority(Map<String, String>? byExtension) {
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

  String _assetSourcePath(String assetPath) {
    if (assetPath.startsWith('assets/')) {
      return assetPath.substring('assets/'.length);
    }
    return assetPath;
  }
}

class _IndexedMedia {
  String? imageAsset;
  String? videoAsset;

  bool get hasMedia => imageAsset != null || videoAsset != null;
}

class _CelebrationMediaSelection {
  const _CelebrationMediaSelection({
    required this.kind,
    required this.mediaAsset,
    required this.soundAsset,
  });

  final _CelebrationMediaKind kind;
  final String mediaAsset;
  final String? soundAsset;
}

enum _CelebrationMediaKind { image, video }
