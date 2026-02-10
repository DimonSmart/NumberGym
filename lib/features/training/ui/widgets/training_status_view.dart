import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/training_state.dart';
import '../view_models/training_status_view_model.dart';

class TrainingStatusView extends StatelessWidget {
  const TrainingStatusView({
    super.key,
    required this.viewModel,
    required this.onRetry,
    required this.onContinue,
    required this.onEndTraining,
    this.showSessionSummaryFullscreen = false,
  });

  final TrainingStatusViewModel viewModel;
  final VoidCallback onRetry;
  final VoidCallback onContinue;
  final VoidCallback onEndTraining;
  final bool showSessionSummaryFullscreen;

  @override
  Widget build(BuildContext context) {
    if (showSessionSummaryFullscreen && viewModel.sessionFinished) {
      return _SessionSummaryCard(
        stats: viewModel.sessionStats!,
        onContinue: onContinue,
        onEndTraining: onEndTraining,
        fullscreen: true,
      );
    }

    final theme = Theme.of(context);
    return Column(
      children: [
        if (viewModel.hasError) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              viewModel.errorMessage ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
        if (viewModel.sessionFinished) ...[
          if (viewModel.hasError) const SizedBox(height: 16),
          _SessionSummaryCard(
            stats: viewModel.sessionStats!,
            onContinue: onContinue,
            onEndTraining: onEndTraining,
          ),
        ],
      ],
    );
  }
}

class _SessionSummaryCard extends StatefulWidget {
  const _SessionSummaryCard({
    required this.stats,
    required this.onContinue,
    required this.onEndTraining,
    this.fullscreen = false,
  });

  final SessionStats stats;
  final VoidCallback onContinue;
  final VoidCallback onEndTraining;
  final bool fullscreen;

  @override
  State<_SessionSummaryCard> createState() => _SessionSummaryCardState();
}

class _SessionSummaryCardState extends State<_SessionSummaryCard> {
  static final RegExp _imagePattern = RegExp(
    r'^assets/images/session_rewards/(\d+)\.(png|jpg|jpeg|webp)$',
    caseSensitive: false,
  );

  List<_IndexedSessionImage> _images = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final parsed = <_IndexedSessionImage>[];
      for (final asset in manifest.listAssets()) {
        final match = _imagePattern.firstMatch(asset);
        if (match == null) continue;
        final number = int.tryParse(match.group(1)!);
        if (number == null) continue;
        parsed.add(_IndexedSessionImage(number: number, asset: asset));
      }
      parsed.sort((a, b) => a.number.compareTo(b.number));
      if (!mounted) return;
      setState(() {
        _images = parsed;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _images = const [];
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final sessionWord = widget.stats.sessionsCompletedToday == 1
        ? 'session'
        : 'sessions';
    final selectedImage = _resolveImageAsset(
      widget.stats.sessionsCompletedToday,
    );
    final buttonGap = widget.fullscreen ? 12.0 : 8.0;
    final cardPadding = widget.fullscreen ? 24.0 : 16.0;
    final borderRadius = widget.fullscreen ? 24.0 : 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = _resolveImageSize(constraints.biggest);
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSessionImage(theme, selectedImage, imageSize),
            const SizedBox(height: 16),
            Text(
              'Session complete',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This session: ${widget.stats.cardsCompleted} cards',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
            Text(
              'This duration: ${_formatDuration(widget.stats.duration)}',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Today: ${widget.stats.sessionsCompletedToday} $sessionWord',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
            Text(
              'Cards today: ${widget.stats.cardsCompletedToday}',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
            Text(
              'Duration today: ${_formatDuration(widget.stats.durationToday)}',
              style: textStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onContinue,
                child: const Text('Continue session'),
              ),
            ),
            SizedBox(height: buttonGap),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: widget.onEndTraining,
                child: const Text('End training'),
              ),
            ),
          ],
        );

        final minHeight = widget.fullscreen
            ? math.max(0.0, constraints.maxHeight - (cardPadding * 2))
            : 0.0;

        return Container(
          width: double.infinity,
          height: widget.fullscreen ? double.infinity : null,
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: widget.fullscreen ? 0.93 : 0.85,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(child: content),
            ),
          ),
        );
      },
    );
  }

  double _resolveImageSize(Size availableSize) {
    if (!widget.fullscreen) {
      return 136.0;
    }
    final byHeight = availableSize.height * 0.34;
    final byWidth = availableSize.width * 0.78;
    final byShortest = availableSize.shortestSide * 0.66;
    final candidate = math.min(byHeight, math.min(byWidth, byShortest));
    return candidate.clamp(170.0, 360.0).toDouble();
  }

  Widget _buildSessionImage(
    ThemeData theme,
    String? selectedImage,
    double imageSize,
  ) {
    if (!_loaded) {
      return SizedBox(
        width: imageSize,
        height: imageSize,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (selectedImage == null) {
      return SizedBox(
        width: imageSize,
        height: imageSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    return SizedBox(
      width: imageSize,
      height: imageSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(selectedImage, fit: BoxFit.cover),
      ),
    );
  }

  String? _resolveImageAsset(int sessionNumber) {
    if (_images.isEmpty) return null;
    final normalizedSessionNumber = sessionNumber <= 0 ? 1 : sessionNumber;
    final index = (normalizedSessionNumber - 1) % _images.length;
    return _images[index].asset;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final paddedSeconds = seconds.toString().padLeft(2, '0');
    return '$minutes:$paddedSeconds';
  }
}

class _IndexedSessionImage {
  const _IndexedSessionImage({required this.number, required this.asset});

  final int number;
  final String asset;
}
