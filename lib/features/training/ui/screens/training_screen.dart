import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/pronunciation_models.dart';
import '../../domain/number_words_task.dart';
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
  bool _sendingPronunciation = false;

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
        final status = _controller.status;
        final isActiveSession = status == TrainerStatus.running ||
          status == TrainerStatus.waitingRecording;
        final controlEnabled = isActiveSession || _controller.hasRemainingCards;
        final feedback = _controller.feedback;
        final feedbackText = feedback?.text;
        final feedbackColor = feedback == null
            ? null
            : _resolveFeedbackColor(theme, feedback.type);
        final hintText = _controller.hintText;
        final isWaitingRecording = _controller.isAwaitingRecording;

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
                          _buildTaskContent(theme, status, hintText, feedbackText,
                              feedbackColor),
                          const SizedBox(height: 16),
                          _buildStatusAndErrors(theme, statusMessage),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTrainingButton(
                    theme,
                    isActiveSession,
                    controlEnabled,
                    isWaitingRecording,
                  ),
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
    bool isActiveSession,
    bool enabled,
    bool isWaitingRecording,
  ) {
    final label = isActiveSession ? 'Stop' : 'Start';
    final icon = isActiveSession
        ? (isWaitingRecording ? Icons.stop_circle : Icons.stop)
        : Icons.play_arrow;
    final backgroundColor =
        isActiveSession ? theme.colorScheme.error : theme.colorScheme.primary;
    final foregroundColor =
        isActiveSession ? theme.colorScheme.onError : theme.colorScheme.onPrimary;

    return SizedBox(
      width: 160,
      height: 48,
      child: FilledButton.icon(
        onPressed: enabled
            ? () async {
                if (isActiveSession) {
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

  Widget _buildTaskContent(
    ThemeData theme,
    TrainerStatus status,
    String? hintText,
    String? feedbackText,
    Color? feedbackColor,
  ) {
    final task = _controller.currentTask;
    if (task == null ||
        task.kind == TrainingTaskKind.numberPronunciation) {
      return _buildNumberPronunciationContent(
        theme,
        status,
        hintText,
        feedbackText,
        feedbackColor,
      );
    }
    if (task.kind == TrainingTaskKind.numberReading) {
      return _buildNumberReadingContent(
        theme,
        task as NumberReadingTask,
        feedbackText,
        feedbackColor,
      );
    }
    return _buildPhrasePronunciationContent(theme);
  }

  Widget _buildNumberPronunciationContent(
    ThemeData theme,
    TrainerStatus status,
    String? hintText,
    String? feedbackText,
    Color? feedbackColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPrompt(theme, _controller.displayText),
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
              visible: status == TrainerStatus.running,
            );
          },
        ),
      ],
    );
  }

  Widget _buildNumberReadingContent(
    ThemeData theme,
    NumberReadingTask task,
    String? feedbackText,
    Color? feedbackColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Choose the correct spelling',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          task.prompt,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: task.options.map((option) {
            return SizedBox(
              width: 220,
              child: FilledButton.tonal(
                onPressed: () => _controller.answerNumberReading(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    option,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          opacity: feedbackText == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: Text(
            feedbackText ?? '',
            style: theme.textTheme.titleMedium?.copyWith(
              color: feedbackColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPhrasePronunciationContent(ThemeData theme) {
    final displayText = _controller.displayText;
    final isRecording = _controller.isRecording;
    final hasRecording = _controller.hasRecording;
    final waiting = _controller.isAwaitingRecording;
    final result = _controller.pronunciationResult;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pronounce the phrase',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          displayText,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            if (!isRecording && !hasRecording)
              FilledButton.icon(
                onPressed: waiting ? _controller.startPronunciationRecording : null,
                icon: const Icon(Icons.mic),
                label: const Text('Record'),
              ),
            if (isRecording)
              FilledButton.icon(
                onPressed: _controller.stopPronunciationRecording,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
              ),
            if (!isRecording && hasRecording)
              FilledButton.tonalIcon(
                onPressed: _sendingPronunciation
                    ? null
                    : () async {
                        await _controller.cancelPronunciationRecording();
                        await _controller.startPronunciationRecording();
                      },
                icon: const Icon(Icons.mic_none),
                label: const Text('Record again'),
              ),
            if (!isRecording && hasRecording)
              FilledButton.icon(
                onPressed: _sendingPronunciation ? null : _handleSendPronunciation,
                icon: _sendingPronunciation
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_sendingPronunciation ? 'Sending...' : 'Send'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _buildPronunciationHelperText(waiting, isRecording, hasRecording),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (result != null) ...[
          const SizedBox(height: 18),
          _buildPronunciationAnalysis(theme, result),
        ],
      ],
    );
  }

  String _buildPronunciationHelperText(
    bool waiting,
    bool isRecording,
    bool hasRecording,
  ) {
    if (isRecording) {
      return 'Recording... tap Stop when done.';
    }
    if (hasRecording) {
      return _sendingPronunciation
          ? 'Uploading for scoring...'
          : 'Review or send your recording for scoring.';
    }
    if (waiting) {
      return 'Tap Record and read the phrase aloud.';
    }
    return 'Waiting to start the next phrase.';
  }

  Widget _buildPronunciationAnalysis(
    ThemeData theme,
    PronunciationAnalysisResult result,
  ) {
    final best = result.best;
    if (best == null) {
      return const SizedBox.shrink();
    }

    Color scoreColor(double score) => _wordScoreColor(theme, score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Pronunciation feedback',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _ScoreChip(
              label: 'Overall',
              score: best.pronScore,
              color: scoreColor(best.pronScore),
            ),
            _ScoreChip(
              label: 'Accuracy',
              score: best.accuracyScore,
              color: scoreColor(best.accuracyScore),
            ),
            _ScoreChip(
              label: 'Fluency',
              score: best.fluencyScore,
              color: scoreColor(best.fluencyScore),
            ),
            _ScoreChip(
              label: 'Completeness',
              score: best.completenessScore,
              color: scoreColor(best.completenessScore),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (best.words.isNotEmpty)
          Column(
            children: [
              Text(
                'Word highlights',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: best.words.map((word) {
                  final color = scoreColor(word.accuracyScore);
                  return Chip(
                    label: Text(
                      '${word.word} (${word.accuracyScore.toStringAsFixed(0)})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    backgroundColor: color.withAlpha(_scaledAlpha(color, 0.18)),
                    side: BorderSide(
                      color: color.withAlpha(_scaledAlpha(color, 0.7)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatusAndErrors(ThemeData theme, String statusMessage) {
    return Column(
      children: [
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
    );
  }

  Color _wordScoreColor(ThemeData theme, double score) {
    if (score >= 80) {
      return Colors.green.shade600;
    }
    if (score >= 60) {
      return Colors.orange.shade600;
    }
    return theme.colorScheme.error;
  }

  Future<void> _handleSendPronunciation() async {
    if (!_controller.hasRecording) return;
    setState(() {
      _sendingPronunciation = true;
    });
    try {
      await _controller.sendPronunciationRecording();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pronunciation scoring failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingPronunciation = false;
        });
      }
    }
  }

  Widget _buildTimerBar(ThemeData theme) {
    final isActive = _controller.status == TrainerStatus.running;
    final duration = _controller.currentCardDuration;

    final taskKeyValue =
        _controller.currentTask?.numberValue ??
        _controller.currentCard?.id ??
        -1;
    return TweenAnimationBuilder<double>(
      key: ValueKey(taskKeyValue),
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
    final status = _controller.status;
    if (status == TrainerStatus.finished) {
      return 'All cards learned. Reset progress to start again.';
    }
    if (status == TrainerStatus.paused) {
      return 'Paused. Tap Start to begin again.';
    }
    if (status == TrainerStatus.waitingRecording) {
      return 'Waiting to record phrase. Start recording when ready.';
    }
    final taskKind = _controller.currentTaskKind;
    if (taskKind == TrainingTaskKind.numberReading) {
      if (status == TrainerStatus.running) {
        return 'Select the correct answer for the number.';
      }
      return 'Tap Start to begin.';
    }
    if (taskKind == TrainingTaskKind.numberPronunciation) {
      if (!_controller.speechReady) {
        return 'Tap Start to request microphone access.';
      }
      if (status == TrainerStatus.running) {
        return 'Listening...';
      }
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
      case TrainingFeedbackType.skipped:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildPrompt(ThemeData theme, String displayText) {
    final prompt = displayText.isEmpty ? '--' : displayText;
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

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          score.toStringAsFixed(0),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
      label: Text(
        label,
        style: theme.textTheme.bodyMedium,
      ),
      side: BorderSide(color: color.withAlpha(_scaledAlpha(color, 0.6))),
      backgroundColor: color.withAlpha(_scaledAlpha(color, 0.12)),
      shape: StadiumBorder(
        side: BorderSide(color: color.withAlpha(_scaledAlpha(color, 0.4))),
      ),
    );
  }
}

int _scaledAlpha(Color color, double factor) {
  final scaled = (color.a * 255.0 * factor).round();
  return scaled.clamp(0, 255);
}
