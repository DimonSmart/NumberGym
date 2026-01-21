import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/training_controller.dart';
import '../widgets/sound_waveform.dart';
import '../widgets/training_background.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

enum _TrainerMenuAction { statistics, settings }

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

  @override
  void initState() {
    super.initState();
    _controller = TrainingController(
      settingsRepository: SettingsRepository(widget.settingsBox),
      progressRepository: ProgressRepository(widget.progressBox),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openOverlay(Widget screen) async {
    await _controller.pauseForOverlay();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => screen,
      ),
    );

    if (!mounted) return;
    await _controller.restoreAfterOverlay();
  }

  Future<void> _openSettings() async {
    await _openOverlay(
      SettingsScreen(
        settingsBox: widget.settingsBox,
        progressBox: widget.progressBox,
      ),
    );
  }

  Future<void> _openStatistics() async {
    await _openOverlay(
      StatisticsScreen(progressBox: widget.progressBox),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final learnedCount = _controller.learnedCount;
        final remainingCount = _controller.remainingCount;
        final statusMessage = _buildStatusMessage();
        final isRunning = _controller.status == TrainerStatus.running;
        final controlEnabled = isRunning || _controller.hasRemainingCards;
        final feedback = _controller.feedback;
        final feedbackText = feedback?.text;
        final feedbackColor = feedback == null
            ? null
            : _resolveFeedbackColor(theme, feedback.type);
        final hintText = _controller.hintText;

        return Scaffold(
          body: TrainingBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          'Numbers Trainer',
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
                        const SizedBox(width: 8),
                        PopupMenuButton<_TrainerMenuAction>(
                          onSelected: (value) {
                            switch (value) {
                              case _TrainerMenuAction.statistics:
                                _openStatistics();
                                break;
                              case _TrainerMenuAction.settings:
                                _openSettings();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _TrainerMenuAction.statistics,
                              child: Row(
                                children: const [
                                  Icon(Icons.bar_chart, size: 18),
                                  SizedBox(width: 8),
                                  Text('Statistics'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: _TrainerMenuAction.settings,
                              child: Row(
                                children: const [
                                  Icon(Icons.settings, size: 18),
                                  SizedBox(width: 8),
                                  Text('Settings'),
                                ],
                              ),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Menu',
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
                          _buildPrompt(theme),
                          if (hintText != null && hintText.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              hintText,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 12),
                          AnimatedOpacity(
                            opacity: feedbackText == null ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              feedbackText ?? '',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: feedbackColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildTimerBar(theme),
                          const SizedBox(height: 12),
                          StreamBuilder<List<double>>(
                            stream: _controller.soundStream,
                            initialData: const [],
                            builder: (context, snapshot) {
                              return SoundWaveform(
                                values: snapshot.data ?? [],
                                visible: isRunning,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            statusMessage,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_controller.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _controller.errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: _controller.retryInitSpeech,
                              child: const Text('Try again'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTrainingButton(theme, isRunning, controlEnabled),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrainingButton(
    ThemeData theme,
    bool isRunning,
    bool enabled,
  ) {
    final label = isRunning ? 'Stop' : 'Start';
    final icon = isRunning ? Icons.stop : Icons.play_arrow;
    final backgroundColor =
        isRunning ? theme.colorScheme.error : theme.colorScheme.primary;
    final foregroundColor =
        isRunning ? theme.colorScheme.onError : theme.colorScheme.onPrimary;

    return SizedBox(
      width: 160,
      height: 48,
      child: FilledButton.icon(
        onPressed: enabled
            ? () async {
                if (isRunning) {
                  await _controller.stopTraining();
                } else {
                  await _controller.startTraining();
                }
              }
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  Widget _buildTimerBar(ThemeData theme) {
    final isActive = _controller.status == TrainerStatus.running;
    final duration = _controller.currentCardDuration;
    
    return TweenAnimationBuilder<double>(
      key: ValueKey(_controller.currentCard?.id ?? -1),
      tween: Tween<double>(begin: 1.0, end: 0.0),
      duration: isActive ? duration : Duration.zero,
      builder: (context, value, child) {
        final displayValue = isActive ? value : 0.0;
        final maxSeconds = duration.inSeconds;
        final secondsRemaining = isActive 
            ? (maxSeconds * displayValue).ceil() 
            : maxSeconds; 

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: displayValue,
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${secondsRemaining}s',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  String _buildStatusMessage() {
    if (_controller.status == TrainerStatus.finished) {
      return 'All cards learned. Reset progress to start again.';
    }
    if (_controller.status == TrainerStatus.paused) {
      return 'Paused. Tap Start to begin again.';
    }
    if (!_controller.speechReady) {
      return 'Tap Start to request microphone access.';
    }
    if (_controller.status == TrainerStatus.running) {
      return 'Listening...';
    }
    return 'Tap Start to begin.';
  }

  Color _resolveFeedbackColor(
    ThemeData theme,
    TrainingFeedbackType type,
  ) {
    switch (type) {
      case TrainingFeedbackType.correct:
        return Colors.green.shade700;
      case TrainingFeedbackType.wrong:
      case TrainingFeedbackType.timeout:
        return Colors.red.shade700;
    }
  }

  Widget _buildPrompt(ThemeData theme) {
    final prompt = _controller.currentCard?.prompt ?? '--';
    final baseStyle = theme.textTheme.displayLarge?.copyWith(
      fontSize: 86,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );

    if (_controller.expectedTokens.isEmpty ||
        _controller.matchedTokens.length != _controller.expectedTokens.length ||
        baseStyle == null) {
      return Text(
        prompt,
        style: baseStyle,
        textAlign: TextAlign.center,
      );
    }

    final matchedStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
    );

    final spans = <TextSpan>[];
    for (var i = 0; i < _controller.expectedTokens.length; i++) {
      final token = _controller.expectedTokens[i];
      spans.add(TextSpan(
        text: token,
        style: _controller.matchedTokens[i] ? matchedStyle : baseStyle,
      ));
      if (i < _controller.expectedTokens.length - 1) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: TextAlign.center,
    );
  }
}
