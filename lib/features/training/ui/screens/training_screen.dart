import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/training_controller.dart';
import '../view_models/listening_numbers_view_model.dart';
import '../view_models/multiple_choice_view_model.dart';
import '../view_models/number_pronunciation_view_model.dart';
import '../view_models/phrase_pronunciation_view_model.dart';
import '../view_models/training_feedback_view_model.dart';
import '../view_models/training_status_view_model.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/listening_numbers_view.dart';
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

class _TrainingScreenState extends State<TrainingScreen> {
  late final TrainingController _controller;
  bool _startingTraining = false;

  static const String _successAnimationPrefix = 'assets/animations/success/';
  static const String _fallbackSuccessAnimation =
      'assets/animations/success/Success.json';
  static const String _failureAnimationAsset =
      'assets/animations/failure/Failure.json';
  static const Duration _overlayTransition = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _controller = TrainingController(
      settingsRepository: SettingsRepository(widget.settingsBox),
      progressRepository: ProgressRepository(widget.progressBox),
      onAutoStop: _handleAutoStop,
    );
    _initializeAndStart();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final learnedCount = _controller.learnedCount;
        final remainingCount = _controller.remainingCount;
        final feedbackViewModel = TrainingFeedbackViewModel.fromFeedback(
          theme: theme,
          feedback: _controller.feedback,
        );
        final statusViewModel = TrainingStatusViewModel.fromState(
          state: _controller.state,
        );

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
                              'Numbers Gym',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$learnedCount learned',
                              style: theme.textTheme.labelMedium,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$remainingCount remaining',
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
                _buildFeedbackOverlay(feedbackViewModel),
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
    final task = _controller.currentTask;
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
    if (task is ListeningNumbersState) {
      final viewModel = ListeningNumbersViewModel.fromState(
        theme: theme,
        task: task,
        feedback: feedbackViewModel,
      );
      return ListeningNumbersView(
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
}
