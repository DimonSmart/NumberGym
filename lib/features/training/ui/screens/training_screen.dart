import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/training_controller.dart';
import '../../domain/training_task.dart';
import '../view_models/listening_view_model.dart';
import '../view_models/multiple_choice_view_model.dart';
import '../view_models/number_pronunciation_view_model.dart';
import '../view_models/phrase_pronunciation_view_model.dart';
import '../view_models/training_feedback_view_model.dart';
import '../view_models/training_status_view_model.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/listening_view.dart';
import '../widgets/multiple_choice_view.dart';
import '../widgets/number_pronunciation_view.dart';
import '../widgets/phrase_pronunciation_view.dart';
import '../widgets/training_background.dart';
import '../widgets/training_status_view.dart';

class TrainingScreen extends StatefulWidget {
  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;

  const TrainingScreen({
    super.key,
    required this.settingsBox,
    required this.progressBox,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin {
  late final TrainingController _controller;
  bool _startingTraining = false;

  static const String _successAnimationPrefix = 'assets/animations/success/';
  static const String _fallbackSuccessAnimation =
      'assets/animations/success/Success.json';
  static const String _failureAnimationAsset =
      'assets/animations/failure/Failure.json';
  static const Duration _overlayTransition = Duration(milliseconds: 200);

  static final RegExp _sliderAssetPattern = RegExp(
    r'^assets/images/sliders/(\d+)_.*\.(png|jpg|jpeg|webp)$',
    caseSensitive: false,
  );
  static const Duration _sliderPeekMoveDuration = Duration(milliseconds: 500);
  static const Duration _sliderPeekHoldDuration = Duration(milliseconds: 500);

  final math.Random _random = math.Random();
  late final AnimationController _sliderPeekController;

  List<_SliderPeekAsset> _sliderAssets = const [];
  _SliderPeekAsset? _activeSliderAsset;
  Animation<Offset>? _sliderPeekAnimation;
  bool _sliderPeekRunning = false;
  int _lastObservedSessionCards = -1;
  int _lastShownPeekMilestone = 0;
  int _pendingPeekMilestone = 0;

  @override
  void initState() {
    super.initState();
    _controller = TrainingController(
      settingsRepository: SettingsRepository(widget.settingsBox),
      progressRepository: ProgressRepository(widget.progressBox),
      onAutoStop: _handleAutoStop,
    );
    _sliderPeekController = AnimationController(
      vsync: this,
      duration: _sliderPeekMoveDuration,
    );
    _initializeAndStart();
    unawaited(_loadSliderAssets());
  }

  @override
  void dispose() {
    _sliderPeekController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeAndStart() async {
    await _controller.initialize();
    if (!mounted) return;
    await _ensureTrainingStarted();
  }

  Future<void> _ensureTrainingStarted() async {
    if (!mounted || _startingTraining) return;
    _startingTraining = true;
    try {
      await _controller.startTraining();
    } finally {
      _startingTraining = false;
    }
  }

  Future<void> _loadSliderAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final parsed = <_SliderPeekAsset>[];
      for (final asset in manifest.listAssets()) {
        final match = _sliderAssetPattern.firstMatch(asset);
        if (match == null) continue;
        final clockPosition = int.tryParse(match.group(1)!);
        if (clockPosition == null || clockPosition < 0 || clockPosition > 11) {
          continue;
        }
        parsed.add(
          _SliderPeekAsset(assetPath: asset, clockPosition: clockPosition),
        );
      }
      parsed.sort((a, b) => a.assetPath.compareTo(b.assetPath));
      if (!mounted) return;
      setState(() {
        _sliderAssets = parsed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sliderAssets = const [];
      });
    }
  }

  void _trackSessionProgress({
    required int cardsCompleted,
    required bool canShowPeek,
  }) {
    if (_lastObservedSessionCards != cardsCompleted) {
      final previous = _lastObservedSessionCards;
      _lastObservedSessionCards = cardsCompleted;
      if (cardsCompleted < previous) {
        _pendingPeekMilestone = 0;
        _lastShownPeekMilestone = 0;
      }
      final milestone = cardsCompleted ~/ 10;
      if (milestone > _lastShownPeekMilestone) {
        _pendingPeekMilestone = milestone;
      }
    }

    if (!canShowPeek) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_tryShowPendingPeek());
    });
  }

  Future<void> _tryShowPendingPeek() async {
    if (_sliderPeekRunning) return;
    if (_pendingPeekMilestone <= _lastShownPeekMilestone) return;
    if (_sliderAssets.isEmpty) return;

    final selected = _sliderAssets[_random.nextInt(_sliderAssets.length)];
    final placement = _placementForClockPosition(selected.clockPosition);
    final animation =
        Tween<Offset>(begin: placement.hiddenOffset, end: Offset.zero).animate(
          CurvedAnimation(parent: _sliderPeekController, curve: Curves.easeOut),
        );

    setState(() {
      _activeSliderAsset = selected;
      _sliderPeekAnimation = animation;
      _sliderPeekRunning = true;
      _lastShownPeekMilestone = _pendingPeekMilestone;
    });

    var timerWasPaused = false;
    try {
      await _controller.pauseTaskTimer();
      timerWasPaused = true;
      await _sliderPeekController.forward(from: 0);
      if (!mounted) return;
      await Future<void>.delayed(_sliderPeekHoldDuration);
      if (!mounted) return;
      await _sliderPeekController.reverse();
    } finally {
      if (timerWasPaused && mounted) {
        await _controller.resumeTaskTimer();
      }
      if (mounted) {
        setState(() {
          _activeSliderAsset = null;
          _sliderPeekAnimation = null;
          _sliderPeekRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final sessionCardsCompleted = _controller.sessionCardsCompleted;
        final sessionTarget = _controller.sessionTargetCards <= 0
            ? _controller.dailyGoalCards
            : _controller.sessionTargetCards;
        final methodLabel =
            _controller.currentLearningMethod?.label ?? 'Training';
        final feedbackViewModel = TrainingFeedbackViewModel.fromFeedback(
          theme: theme,
          feedback: _controller.feedback,
        );
        final statusViewModel = TrainingStatusViewModel.fromState(
          state: _controller.state,
        );
        final canShowPeek =
            _controller.feedback == null &&
            _controller.celebration == null &&
            !statusViewModel.sessionFinished &&
            _controller.currentTask != null;

        _trackSessionProgress(
          cardsCompleted: sessionCardsCompleted,
          canShowPeek: canShowPeek,
        );

        if (statusViewModel.sessionFinished) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: TrainingBackground(
              child: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: TrainingStatusView(
                  viewModel: statusViewModel,
                  onRetry: _handleRetry,
                  onContinue: _handleContinueSession,
                  onEndTraining: _handleStopTraining,
                  showSessionSummaryFullscreen: true,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: TrainingBackground(
            child: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(
                              methodLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Session: $sessionCardsCompleted/$sessionTarget',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildTaskView(theme, feedbackViewModel),
                              const SizedBox(height: 16),
                              TrainingStatusView(
                                viewModel: statusViewModel,
                                onRetry: _handleRetry,
                                onContinue: _handleContinueSession,
                                onEndTraining: _handleStopTraining,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStopButton(theme),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                _buildSliderPeekOverlay(context),
                _buildFeedbackOverlay(feedbackViewModel),
                _buildCelebrationOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskView(
    ThemeData theme,
    TrainingFeedbackViewModel feedbackViewModel,
  ) {
    final taskView = _buildTaskViewContent(theme, feedbackViewModel);
    return IgnorePointer(
      ignoring: _sliderPeekRunning,
      child: TickerMode(enabled: !_sliderPeekRunning, child: taskView),
    );
  }

  Widget _buildTaskViewContent(
    ThemeData theme,
    TrainingFeedbackViewModel feedbackViewModel,
  ) {
    final task = _controller.currentTask;
    if (task == null) {
      return const SizedBox.shrink();
    }
    if (task is MultipleChoiceState) {
      final viewModel = MultipleChoiceViewModel.fromState(
        theme: theme,
        task: task,
        feedback: feedbackViewModel,
      );
      return MultipleChoiceView(
        viewModel: viewModel,
        onOptionSelected: _controller.selectOption,
      );
    }
    if (task is ListeningState) {
      final viewModel = ListeningViewModel.fromState(
        theme: theme,
        task: task,
        feedback: feedbackViewModel,
      );
      return ListeningView(
        viewModel: viewModel,
        onOptionSelected: _controller.selectOption,
        onReplay: _controller.repeatListeningPrompt,
      );
    }
    if (task is PhrasePronunciationState) {
      final viewModel = PhrasePronunciationViewModel.fromState(task: task);
      return PhrasePronunciationView(
        viewModel: viewModel,
        soundStream: _controller.soundStream,
        onStartRecording: _controller.startPronunciationRecording,
        onStopRecording: _controller.stopPronunciationRecording,
        onRecordAgain: _handleRecordAgain,
        onSendRecording: _handleSendPronunciation,
        onCompleteReview: _controller.completePronunciationReview,
      );
    }

    final viewModel = NumberPronunciationViewModel.fromState(
      task: _controller.numberPronunciationState,
      feedback: feedbackViewModel,
    );
    return NumberPronunciationView(
      viewModel: viewModel,
      soundStream: _controller.soundStream,
    );
  }

  Widget _buildStopButton(ThemeData theme) {
    return SizedBox(
      width: 200,
      height: 48,
      child: FilledButton.icon(
        onPressed: _handleStopTraining,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
        ),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('End training'),
      ),
    );
  }

  Widget _buildSliderPeekOverlay(BuildContext context) {
    final asset = _activeSliderAsset;
    final animation = _sliderPeekAnimation;
    if (asset == null || animation == null) {
      return const SizedBox.shrink();
    }
    final placement = _placementForClockPosition(asset.clockPosition);
    final sliderSize = _resolveSliderSize(context);
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
              child: Image.asset(asset.assetPath, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }

  Size _resolveSliderSize(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Size(screen.width * 0.5, screen.height * 0.5);
  }

  _SliderPeekPlacement _placementForClockPosition(int clockPosition) {
    switch (clockPosition) {
      case 0:
        return const _SliderPeekPlacement(
          alignment: Alignment(0.0, -1.0),
          hiddenOffset: Offset(0.0, -1.0),
        );
      case 1:
        return const _SliderPeekPlacement(
          alignment: Alignment(0.7, -1.0),
          hiddenOffset: Offset(0.0, -1.0),
        );
      case 2:
        return const _SliderPeekPlacement(
          alignment: Alignment(1.0, -0.7),
          hiddenOffset: Offset(1.0, 0.0),
        );
      case 3:
        return const _SliderPeekPlacement(
          alignment: Alignment(1.0, 0.0),
          hiddenOffset: Offset(1.0, 0.0),
        );
      case 4:
        return const _SliderPeekPlacement(
          alignment: Alignment(1.0, 0.7),
          hiddenOffset: Offset(1.0, 0.0),
        );
      case 5:
        return const _SliderPeekPlacement(
          alignment: Alignment(0.7, 1.0),
          hiddenOffset: Offset(0.0, 1.0),
        );
      case 6:
        return const _SliderPeekPlacement(
          alignment: Alignment(0.0, 1.0),
          hiddenOffset: Offset(0.0, 1.0),
        );
      case 7:
        return const _SliderPeekPlacement(
          alignment: Alignment(-0.7, 1.0),
          hiddenOffset: Offset(0.0, 1.0),
        );
      case 8:
        return const _SliderPeekPlacement(
          alignment: Alignment(-1.0, 0.7),
          hiddenOffset: Offset(-1.0, 0.0),
        );
      case 9:
        return const _SliderPeekPlacement(
          alignment: Alignment(-1.0, 0.0),
          hiddenOffset: Offset(-1.0, 0.0),
        );
      case 10:
        return const _SliderPeekPlacement(
          alignment: Alignment(-1.0, -0.7),
          hiddenOffset: Offset(-1.0, 0.0),
        );
      case 11:
        return const _SliderPeekPlacement(
          alignment: Alignment(-0.7, -1.0),
          hiddenOffset: Offset(0.0, -1.0),
        );
      default:
        return const _SliderPeekPlacement(
          alignment: Alignment(0.0, -1.0),
          hiddenOffset: Offset(0.0, -1.0),
        );
    }
  }

  Widget _buildFeedbackOverlay(TrainingFeedbackViewModel feedbackViewModel) {
    final feedback = feedbackViewModel.feedback;
    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: _overlayTransition,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: feedbackViewModel.showOverlay && feedback != null
            ? FeedbackOverlay(
                key: ValueKey(feedback),
                feedback: feedback,
                accentColor: feedbackViewModel.overlayColor,
                successAssetPrefix: _successAnimationPrefix,
                fallbackSuccessAsset: _fallbackSuccessAnimation,
                failureAsset: _failureAnimationAsset,
                animationSize: _resolveOverlayAnimationSize(context),
              )
            : const SizedBox.shrink(key: ValueKey('feedback-hidden')),
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    final celebration = _controller.celebration;
    if (celebration == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: CelebrationOverlay(
        key: ValueKey(celebration.eventId),
        celebration: celebration,
        onContinue: _handleContinueAfterCelebration,
      ),
    );
  }

  double _resolveOverlayAnimationSize(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final base = shortest * 0.7;
    final cap = size.height * 0.4;
    final candidate = base < cap ? base : cap;
    return candidate.clamp(260.0, 420.0).toDouble();
  }

  Future<void> _handleStopTraining() async {
    await _controller.stopTraining();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleRetry() async {
    await _controller.retryInitSpeech();
    if (!mounted) return;
    await _ensureTrainingStarted();
  }

  Future<void> _handleRecordAgain() async {
    await _controller.cancelPronunciationRecording();
    await _controller.startPronunciationRecording();
  }

  Future<void> _handleSendPronunciation() async {
    if (!_controller.hasRecording) return;
    try {
      await _controller.sendPronunciationRecording();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pronunciation scoring failed: $error')),
      );
    }
  }

  void _handleAutoStop() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleContinueSession() async {
    await _controller.continueSession();
  }

  Future<void> _handleContinueAfterCelebration() async {
    await _controller.continueAfterCelebration();
  }
}

class _SliderPeekAsset {
  const _SliderPeekAsset({
    required this.assetPath,
    required this.clockPosition,
  });

  final String assetPath;
  final int clockPosition;
}

class _SliderPeekPlacement {
  const _SliderPeekPlacement({
    required this.alignment,
    required this.hiddenOffset,
  });

  final Alignment alignment;
  final Offset hiddenOffset;
}
