import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../widgets/slider_peek.dart';
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
  late final SettingsRepository _settingsRepository;
  late final TrainingController _controller;
  bool _startingTraining = false;

  static const String _successAnimationPrefix = 'assets/animations/success/';
  static const String _fallbackSuccessAnimation =
      'assets/animations/success/Success.json';
  static const String _failureAnimationAsset =
      'assets/animations/failure/Failure.json';
  static const Duration _overlayTransition = Duration(milliseconds: 200);
  static const Duration _autoSimulationTickDelay = Duration(milliseconds: 90);
  static const Duration _autoSimulationAfterFeedbackDelay = Duration(
    milliseconds: 260,
  );
  static const Duration _autoSimulationCelebrationDelay = Duration(
    milliseconds: 1800,
  );
  static const Duration _autoSimulationSessionSummaryDelay = Duration(
    milliseconds: 900,
  );

  final math.Random _random = math.Random();
  late final AnimationController _sliderPeekController;

  List<SliderPeekAsset> _sliderAssets = const [];
  SliderPeekAsset? _activeSliderAsset;
  Animation<Offset>? _sliderPeekAnimation;
  bool _sliderPeekRunning = false;
  int _lastObservedSessionCards = -1;
  int _lastShownPeekMilestone = 0;
  int _pendingPeekMilestone = 0;
  bool _autoSimulationEnabled = false;
  int _autoSimulationContinueLimit = 0;
  int _autoSimulationContinuesUsed = 0;
  bool _autoSimulationActionRunning = false;
  DateTime? _feedbackClearedAt;
  DateTime? _celebrationVisibleSince;
  DateTime? _sessionSummaryVisibleSince;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _controller = TrainingController(
      settingsRepository: _settingsRepository,
      progressRepository: ProgressRepository(widget.progressBox),
      onAutoStop: _handleAutoStop,
    );
    _loadAutoSimulationSettings();
    _sliderPeekController = AnimationController(
      vsync: this,
      duration: sliderPeekMoveDuration,
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
    _autoSimulationContinuesUsed = 0;
    _feedbackClearedAt = null;
    _celebrationVisibleSince = null;
    _sessionSummaryVisibleSince = null;
    await _controller.initialize();
    if (!mounted) return;
    await _ensureTrainingStarted();
  }

  void _loadAutoSimulationSettings() {
    _autoSimulationEnabled = _settingsRepository.readAutoSimulationEnabled();
    _autoSimulationContinueLimit = _settingsRepository
        .readAutoSimulationContinueCount();
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
      final parsed = await loadSliderPeekAssets();
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

    final selected = pickRandomSliderPeekAsset(
      assets: _sliderAssets,
      random: _random,
    );
    final animation = createSliderPeekAnimation(
      controller: _sliderPeekController,
      clockPosition: selected.clockPosition,
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
      await playSliderPeekSequence(
        controller: _sliderPeekController,
        holdDuration: sliderPeekHoldDuration,
        shouldContinue: () => mounted,
      );
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
        _scheduleAutoSimulation();

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

  void _scheduleAutoSimulation() {
    if (!_autoSimulationEnabled || _autoSimulationActionRunning) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_tryRunAutoSimulation());
    });
  }

  Future<void> _tryRunAutoSimulation() async {
    if (!_autoSimulationEnabled || _autoSimulationActionRunning) {
      return;
    }

    _autoSimulationActionRunning = true;
    try {
      await Future<void>.delayed(_autoSimulationTickDelay);
      if (!mounted) return;

      final state = _controller.state;
      final now = DateTime.now();

      if (state.feedback != null) {
        _feedbackClearedAt = null;
        return;
      }

      _feedbackClearedAt ??= now;
      if (now.difference(_feedbackClearedAt!) <
          _autoSimulationAfterFeedbackDelay) {
        return;
      }

      if (state.celebration != null) {
        _sessionSummaryVisibleSince = null;
        _celebrationVisibleSince ??= now;
        if (now.difference(_celebrationVisibleSince!) <
            _autoSimulationCelebrationDelay) {
          return;
        }
        _celebrationVisibleSince = null;
        await _controller.continueAfterCelebration();
        return;
      }
      _celebrationVisibleSince = null;

      if (state.sessionStats != null) {
        _sessionSummaryVisibleSince ??= now;
        if (now.difference(_sessionSummaryVisibleSince!) <
            _autoSimulationSessionSummaryDelay) {
          return;
        }
        if (_autoSimulationContinuesUsed >= _autoSimulationContinueLimit) {
          return;
        }
        _sessionSummaryVisibleSince = null;
        _autoSimulationContinuesUsed += 1;
        await _controller.continueSession();
        return;
      }
      _sessionSummaryVisibleSince = null;

      if (_sliderPeekRunning) {
        return;
      }

      final task = state.currentTask;
      if (task == null) {
        return;
      }
      if (task is ListeningState && task.isPromptPlaying) {
        return;
      }

      final outcome = _random.nextDouble() < 0.999
          ? TrainingOutcome.correct
          : TrainingOutcome.wrong;
      await _controller.completeCurrentTaskWithOutcome(
        outcome,
        simulatedUserInteraction: true,
      );
    } finally {
      _autoSimulationActionRunning = false;
    }
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
    return SliderPeekOverlay(
      assetPath: asset.assetPath,
      clockPosition: asset.clockPosition,
      animation: animation,
    );
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
