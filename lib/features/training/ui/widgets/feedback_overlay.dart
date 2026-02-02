import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../domain/training_state.dart';

class FeedbackOverlay extends StatefulWidget {
  const FeedbackOverlay({
    super.key,
    required this.feedback,
    required this.accentColor,
    required this.successAssetPrefix,
    required this.fallbackSuccessAsset,
    required this.failureAsset,
    this.animationSize = 240,
  });

  final TrainingFeedback feedback;
  final Color accentColor;
  final String successAssetPrefix;
  final String fallbackSuccessAsset;
  final String failureAsset;
  final double animationSize;

  @override
  State<FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<FeedbackOverlay> {
  final Random _random = Random();
  final Map<String, Future<ByteData>> _assetLoads = {};
  List<String> _successAssets = const [];
  String? _activeAsset;
  bool _manifestReady = false;
  Set<String> _availableAssets = const {};

  @override
  void initState() {
    super.initState();
    _selectAssetForFeedback();
    _loadSuccessAssets();
  }

  @override
  void didUpdateWidget(FeedbackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedback != widget.feedback) {
      _selectAssetForFeedback();
    }
  }

  Future<void> _loadSuccessAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets();
      final assets = allAssets
          .where(
            (key) =>
                key.startsWith(widget.successAssetPrefix) &&
                key.endsWith('.json'),
          )
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _successAssets = assets;
        _availableAssets = allAssets.toSet();
        _manifestReady = true;
      });
      _selectAssetForFeedback();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _successAssets = const [];
        _availableAssets = const {};
        _manifestReady = true;
      });
    }
  }

  void _selectAssetForFeedback() {
    final feedback = widget.feedback;
    String? asset;
    if (feedback.type == TrainingFeedbackType.correct) {
      final pool =
          _successAssets.isEmpty ? [widget.fallbackSuccessAsset] : _successAssets;
      final candidate = pool[_random.nextInt(pool.length)];
      asset = _canUseAsset(candidate) ? candidate : null;
    } else {
      asset = _canUseAsset(widget.failureAsset) ? widget.failureAsset : null;
    }
    if (_activeAsset == asset) return;
    if (mounted) {
      setState(() {
        _activeAsset = asset;
      });
    } else {
      _activeAsset = asset;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _activeAsset ??
        (widget.feedback.type == TrainingFeedbackType.correct
            ? widget.fallbackSuccessAsset
            : null);
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.animationSize,
                height: widget.animationSize,
                child: _buildAnimation(
                  asset: asset,
                  fallbackIcon: widget.feedback.type ==
                          TrainingFeedbackType.correct
                      ? Icons.check_circle
                      : Icons.cancel,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.feedback.text,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: widget.accentColor,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation({
    required String? asset,
    required IconData fallbackIcon,
  }) {
    if (!_manifestReady || asset == null || !_availableAssets.contains(asset)) {
      return _buildFallbackIcon(fallbackIcon);
    }
    final future =
        _assetLoads.putIfAbsent(asset, () => rootBundle.load(asset));
    return FutureBuilder<ByteData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildFallbackIcon(fallbackIcon);
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return Lottie.memory(
          snapshot.data!.buffer.asUint8List(),
          repeat: false,
          fit: BoxFit.contain,
        );
      },
    );
  }

  Widget _buildFallbackIcon(IconData icon) {
    return Center(
      child: Icon(
        icon,
        size: 140,
        color: widget.accentColor,
      ),
    );
  }

  bool _canUseAsset(String asset) {
    if (!_manifestReady) return false;
    return _availableAssets.contains(asset);
  }
}
