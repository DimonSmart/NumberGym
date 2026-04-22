import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/training_state.dart';
import 'celebration_media_resolver.dart';

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
  CelebrationMediaSelection? _selection;
  Object? _loadError;
  bool _loading = true;
  int _loadVersion = 0;
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
    final oldCelebration = oldWidget.celebration;
    final newCelebration = widget.celebration;
    if (oldCelebration.eventId != newCelebration.eventId ||
        oldCelebration.counter != newCelebration.counter) {
      unawaited(_prepareMedia());
    }
  }

  @override
  void dispose() {
    _loadVersion += 1;
    unawaited(_disposePlayback());
    super.dispose();
  }

  Future<void> _prepareMedia() async {
    final loadVersion = ++_loadVersion;
    await _disposePlayback();
    if (!_isLoadActive(loadVersion)) return;

    setState(() {
      _loading = true;
      _selection = null;
      _loadError = null;
    });

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!_isLoadActive(loadVersion)) return;

      final selection = _resolveSelection(
        assets: manifest.listAssets(),
        counter: widget.celebration.counter,
      );
      if (!_isLoadActive(loadVersion)) return;

      if (selection != null) {
        if (selection.kind == CelebrationMediaKind.video) {
          final controller = VideoPlayerController.asset(selection.mediaAsset);
          _videoController = controller;
          await controller.initialize();
          if (!_isLoadActive(loadVersion) || _videoController != controller) {
            if (_videoController == controller) {
              _videoController = null;
              await controller.dispose();
            }
            return;
          }

          await controller.play();
          if (!_isLoadActive(loadVersion) || _videoController != controller) {
            if (_videoController == controller) {
              _videoController = null;
              await controller.dispose();
            }
            return;
          }
        } else if (selection.soundAsset != null) {
          final player = _audioPlayer ??= AudioPlayer();
          await player.stop();
          if (!_isLoadActive(loadVersion)) return;

          await player.play(
            AssetSource(_assetSourcePath(selection.soundAsset!)),
          );
          if (!_isLoadActive(loadVersion)) return;
        }
      }

      if (!_isLoadActive(loadVersion)) return;
      setState(() {
        _selection = selection;
        _loading = false;
      });
    } catch (error, stackTrace) {
      appLogW(
        'celebration',
        'Failed to load reward media',
        error: error,
        st: stackTrace,
      );
      if (!_isLoadActive(loadVersion)) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  bool _isLoadActive(int loadVersion) {
    return mounted && loadVersion == _loadVersion;
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
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopMetaRow(theme),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Text(
                                'Milestone reached',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                'You mastered',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                primaryMasteredText,
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  shadows: [
                                    Shadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.28),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (hasConcreteMasteredValue &&
                                categoryLabel.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      categoryLabel,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: mediaSize,
                                  maxHeight: mediaSize,
                                ),
                                child: _buildMediaContent(theme),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: widget.onContinue,
                            child: const Text('Continue'),
                          ),
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

  Widget _buildTopMetaRow(ThemeData theme) {
    final methodLabel = widget.celebration.learningMethodLabel.trim();
    final leftText = methodLabel.isEmpty ? 'Training' : methodLabel;
    final sessionText = _resolveSessionText();
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.92),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            leftText,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text(sessionText, style: textStyle),
      ],
    );
  }

  String _resolveSessionText() {
    final celebration = widget.celebration;
    final target = celebration.sessionTargetCards <= 0
        ? celebration.sessionCardsCompleted
        : celebration.sessionTargetCards;
    return 'Session: ${celebration.sessionCardsCompleted}/$target';
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

    if (_selection!.kind == CelebrationMediaKind.image) {
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

  CelebrationMediaSelection? _resolveSelection({
    required Iterable<String> assets,
    required int counter,
  }) {
    return CelebrationMediaResolver.resolve(assets: assets, counter: counter);
  }

  String _assetSourcePath(String assetPath) {
    if (assetPath.startsWith('assets/')) {
      return assetPath.substring('assets/'.length);
    }
    return assetPath;
  }
}
