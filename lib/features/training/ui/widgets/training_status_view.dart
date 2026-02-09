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
  });

  final TrainingStatusViewModel viewModel;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showMessage = viewModel.message.isNotEmpty;
    return Column(
      children: [
        if (showMessage)
          Text(
            viewModel.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        if (viewModel.hasError) ...[
          if (showMessage) const SizedBox(height: 16),
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
          if (showMessage || viewModel.hasError) const SizedBox(height: 16),
          _SessionSummaryCard(
            stats: viewModel.sessionStats!,
            onContinue: onContinue,
          ),
        ],
      ],
    );
  }
}

class _SessionSummaryCard extends StatefulWidget {
  const _SessionSummaryCard({required this.stats, required this.onContinue});

  final SessionStats stats;
  final VoidCallback onContinue;

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.85,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSessionImage(theme, selectedImage),
          const SizedBox(height: 10),
          Text(
            'Session complete',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This session: ${widget.stats.cardsCompleted} cards',
            style: textStyle,
          ),
          Text(
            'This duration: ${_formatDuration(widget.stats.duration)}',
            style: textStyle,
          ),
          const SizedBox(height: 4),
          Text(
            'Today: ${widget.stats.sessionsCompletedToday} $sessionWord',
            style: textStyle,
          ),
          Text(
            'Cards today: ${widget.stats.cardsCompletedToday}',
            style: textStyle,
          ),
          Text(
            'Duration today: ${_formatDuration(widget.stats.durationToday)}',
            style: textStyle,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.onContinue,
            child: const Text('Continue session'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionImage(ThemeData theme, String? selectedImage) {
    const imageSize = 136.0;
    if (!_loaded) {
      return const SizedBox(
        width: imageSize,
        height: imageSize,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
