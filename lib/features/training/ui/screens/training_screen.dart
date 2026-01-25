import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/pronunciation_models.dart';
import '../../domain/training_controller.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/sound_wave_indicator.dart';
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

  static const String _successAnimationPrefix = 'assets/animations/success/';
  static const String _fallbackSuccessAnimation =
      'assets/animations/success/Success.lottie';
  static const String _failureAnimationAsset =
      'assets/animations/failure/Failure.lottie';
  static const Duration _overlayTransition = Duration(milliseconds: 250);

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

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => screen));

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
    final language = SettingsRepository(
      widget.settingsBox,
    ).readLearningLanguage();
    await _openOverlay(
      StatisticsScreen(progressBox: widget.progressBox, language: language),
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
        final isActiveSession =
            status == TrainerStatus.running ||
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
                              _buildTaskContent(
                                theme,
                                status,
                                hintText,
                                feedbackText,
                                feedbackColor,
                              ),
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
                _buildFeedbackOverlay(theme, feedback, feedbackColor),
              ],
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
    final backgroundColor = isActiveSession
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final foregroundColor = isActiveSession
        ? theme.colorScheme.onError
        : theme.colorScheme.onPrimary;

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
    if (task == null || task.kind == TrainingTaskKind.numberPronunciation) {
      return _buildNumberPronunciationContent(
        theme,
        status,
        hintText,
        feedbackText,
        feedbackColor,
      );
    }
    if (task is MultipleChoiceState &&
        task.kind == TrainingTaskKind.numberToWord) {
      return _buildNumberToWordContent(
        theme,
        task,
        feedbackText,
        feedbackColor,
      );
    }
    if (task is MultipleChoiceState &&
        task.kind == TrainingTaskKind.wordToNumber) {
      return _buildWordToNumberContent(
        theme,
        task,
        feedbackText,
        feedbackColor,
      );
    }
    if (task is PhrasePronunciationState) {
      return _buildPhrasePronunciationContent(theme, task);
    }
    return _buildNumberPronunciationContent(
      theme,
      status,
      hintText,
      feedbackText,
      feedbackColor,
    );
  }

  Widget _buildFeedbackOverlay(
    ThemeData theme,
    TrainingFeedback? feedback,
    Color? feedbackColor,
  ) {
    final show =
        feedback != null &&
        (feedback.type == TrainingFeedbackType.correct ||
            feedback.type == TrainingFeedbackType.wrong ||
            feedback.type == TrainingFeedbackType.timeout);
    final resolvedColor = feedbackColor ?? theme.colorScheme.primary;

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
        child: show
            ? FeedbackOverlay(
                key: ValueKey(feedback),
                feedback: feedback,
                accentColor: resolvedColor,
                successAssetPrefix: _successAnimationPrefix,
                fallbackSuccessAsset: _fallbackSuccessAnimation,
                failureAsset: _failureAnimationAsset,
              )
            : const SizedBox.shrink(key: ValueKey('feedback-hidden')),
      ),
    );
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
        _buildSpeechRecognitionFeedback(theme),
        SoundWaveIndicator(
          stream: _controller.soundStream,
          visible: status == TrainerStatus.running,
        ),
      ],
    );
  }

  Widget _buildNumberToWordContent(
    ThemeData theme,
    MultipleChoiceState task,
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
                onPressed: () => _controller.selectOption(option),
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
        const SizedBox(height: 16),
        _buildTimerBar(theme),
      ],
    );
  }

  Widget _buildWordToNumberContent(
    ThemeData theme,
    MultipleChoiceState task,
    String? feedbackText,
    Color? feedbackColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Choose the correct number',
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
            fontSize: 42, // Smaller font for text prompt
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
              width: 100, // Smaller width for digits
              child: FilledButton.tonal(
                onPressed: () => _controller.selectOption(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    option,
                    style: theme.textTheme.headlineSmall,
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
        const SizedBox(height: 16),
        _buildTimerBar(theme),
      ],
    );
  }

  Widget _buildPhrasePronunciationContent(
    ThemeData theme,
    PhrasePronunciationState task,
  ) {
    final displayText = task.displayText;
    final flow = task.flow;
    final isRecording = flow == PhraseFlow.recording;
    final hasRecording = task.hasRecording;
    final waiting = flow == PhraseFlow.waiting;
    final isReviewing = flow == PhraseFlow.reviewing;
    final result = task.result;
    final isSending = _sendingPronunciation || flow == PhraseFlow.sending;

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
        _buildPronunciationPhrase(theme, displayText, result),
        if (result != null) ...[
          const SizedBox(height: 12),
          _buildPronunciationSummary(theme, result),
        ],
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            if (!isRecording && !hasRecording && !isReviewing)
              FilledButton.icon(
                onPressed: waiting
                    ? _controller.startPronunciationRecording
                    : null,
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
            if (!isRecording && (hasRecording || isReviewing))
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
            if (!isRecording && hasRecording && !isReviewing)
              FilledButton.icon(
                onPressed: _sendingPronunciation
                    ? null
                    : _handleSendPronunciation,
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
            if (!isRecording && isReviewing)
              FilledButton.icon(
                onPressed: _controller.completePronunciationReview,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _buildPronunciationHelperText(
            waiting,
            isRecording,
            hasRecording,
            isReviewing,
            isSending,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SoundWaveIndicator(
          stream: _controller.soundStream,
          visible: isRecording,
        ),
      ],
    );
  }

  String _buildPronunciationHelperText(
    bool waiting,
    bool isRecording,
    bool hasRecording,
    bool isReviewing,
    bool isSending,
  ) {
    if (isRecording) {
      return 'Recording... tap Stop when done.';
    }
    if (isReviewing) {
      return 'Review your pronunciation and tap Next to continue.';
    }
    if (hasRecording) {
      return isSending
          ? 'Uploading for scoring...'
          : 'Review or send your recording for scoring.';
    }
    if (waiting) {
      return 'Tap Record and read the phrase aloud.';
    }
    return 'Waiting to start the next phrase.';
  }

  Widget _buildPronunciationPhrase(
    ThemeData theme,
    String displayText,
    PronunciationAnalysisResult? result,
  ) {
    final baseStyle =
        theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
    final resolvedText = (result?.displayText?.trim().isNotEmpty ?? false)
        ? result!.displayText!.trim()
        : displayText;
    final best = result?.best;

    if (best == null || best.words.isEmpty) {
      return Text(resolvedText, style: baseStyle, textAlign: TextAlign.center);
    }

    final tokens = _tokenizePhrase(resolvedText);
    final spans = <InlineSpan>[];
    var wordIndex = 0;

    for (final token in tokens) {
      if (!token.isWord) {
        spans.add(TextSpan(text: token.text, style: baseStyle));
        continue;
      }
      if (wordIndex >= best.words.length) {
        spans.add(TextSpan(text: token.text, style: baseStyle));
        continue;
      }
      final word = best.words[wordIndex];
      wordIndex += 1;
      final color = _wordScoreColor(theme, word.accuracyScore);
      final tooltip = _buildWordTooltip(word);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Tooltip(
            message: tooltip,
            triggerMode: TooltipTriggerMode.tap,
            decoration: BoxDecoration(
              color: theme.colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: color, width: 2)),
              ),
              child: Text(token.text, style: baseStyle.copyWith(color: color)),
            ),
          ),
        ),
      );
    }

    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
  }

  Widget _buildPronunciationSummary(
    ThemeData theme,
    PronunciationAnalysisResult result,
  ) {
    final best = result.best;
    if (best == null) {
      return const SizedBox.shrink();
    }
    final recommendation = _extractRecommendation(result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPronunciationLegend(theme),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildScoreIndicator(
                theme,
                label: 'Accuracy',
                score: best.accuracyScore,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildScoreIndicator(
                theme,
                label: 'Fluency',
                score: best.fluencyScore,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildScoreIndicator(
                theme,
                label: 'Completeness',
                score: best.completenessScore,
              ),
            ),
          ],
        ),
        if (recommendation != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              recommendation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPronunciationLegend(ThemeData theme) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(color: Colors.green.shade600, label: 'Correct'),
        _LegendItem(color: Colors.orange.shade600, label: 'Almost'),
        _LegendItem(color: theme.colorScheme.error, label: 'Wrong'),
      ],
    );
  }

  Widget _buildScoreIndicator(
    ThemeData theme, {
    required String label,
    required double score,
  }) {
    final normalized = (score / 100).clamp(0.0, 1.0);
    final color = _wordScoreColor(theme, score);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score.toStringAsFixed(0),
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _buildWordTooltip(PronunciationWord word) {
    final buffer = StringBuffer();
    buffer.writeln(word.word);
    buffer.writeln('Accuracy: ${word.accuracyScore.toStringAsFixed(0)}');
    final error = word.errorType?.trim();
    if (error != null && error.isNotEmpty && error.toLowerCase() != 'none') {
      buffer.writeln('Error: $error');
    }
    if (word.phonemes.isNotEmpty) {
      final phonemes = word.phonemes
          .take(6)
          .map(
            (phoneme) =>
                '${phoneme.phoneme} ${phoneme.accuracyScore.toStringAsFixed(0)}',
          )
          .join(', ');
      buffer.writeln('Phonemes: $phonemes');
    }
    return buffer.toString().trim();
  }

  String? _extractRecommendation(PronunciationAnalysisResult result) {
    final raw = result.rawJson;
    if (raw == null) return null;
    const keys = {
      'recommendation',
      'recommendations',
      'suggestion',
      'suggestions',
      'feedback',
      'advice',
      'note',
      'notes',
      'message',
      'comment',
      'comments',
      'hint',
      'hints',
    };
    final found = _findFirstStringByKey(raw, keys, 0);
    if (found == null) return null;
    final trimmed = found.trim();
    if (trimmed.isEmpty) return null;
    const maxLength = 420;
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }

  String? _findFirstStringByKey(dynamic node, Set<String> keys, int depth) {
    if (node == null || depth > 6) return null;
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        final value = entry.value;
        if (keys.contains(key) && value is String && value.trim().isNotEmpty) {
          return value;
        }
        final nested = _findFirstStringByKey(value, keys, depth + 1);
        if (nested != null) return nested;
      }
    } else if (node is List) {
      for (final item in node) {
        final nested = _findFirstStringByKey(item, keys, depth + 1);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  List<_PhraseToken> _tokenizePhrase(String text) {
    final tokenRegex = RegExp(
      r"[\\p{L}\\p{N}']+|[^\\p{L}\\p{N}']+",
      unicode: true,
    );
    final wordRegex = RegExp(r"^[\\p{L}\\p{N}']+$", unicode: true);
    return tokenRegex.allMatches(text).map((match) {
      final token = match.group(0) ?? '';
      return _PhraseToken(token, wordRegex.hasMatch(token));
    }).toList();
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

    final taskKeyValue = _controller.currentTask?.numberValue ?? -1;
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

  Widget _buildSpeechRecognitionFeedback(ThemeData theme) {
    final expectedTokens = _controller.expectedTokens;
    final matchedIndices = _controller.lastMatchedIndices;
    final heardTokens = _controller.lastHeardTokens;
    final heardText = _controller.lastHeardText?.trim() ?? '';
    final heardDisplay =
        (heardTokens.isNotEmpty ? heardTokens.join(' ') : heardText).trim();
    final previewTokens = _controller.previewHeardTokens;
    final previewText = _controller.previewHeardText?.trim() ?? '';
    final previewDisplay =
        (previewTokens.isNotEmpty ? previewTokens.join(' ') : previewText)
            .trim();
    final previewIndices = _controller.previewMatchedIndices;

    if (heardDisplay.isEmpty &&
        matchedIndices.isEmpty &&
        previewDisplay.isEmpty &&
        previewIndices.isEmpty) {
      return const SizedBox(height: 12);
    }

    final matchedTokens = <String>[];
    for (final index in matchedIndices) {
      if (index >= 0 && index < expectedTokens.length) {
        matchedTokens.add(expectedTokens[index]);
      }
    }
    final matchedDisplay = matchedTokens.isEmpty
        ? '--'
        : matchedTokens.join(' ');
    final previewMatchedTokens = <String>[];
    for (final index in previewIndices) {
      if (index >= 0 && index < expectedTokens.length) {
        previewMatchedTokens.add(expectedTokens[index]);
      }
    }
    final previewMatchedDisplay = previewMatchedTokens.isEmpty
        ? '--'
        : previewMatchedTokens.join(' ');
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.2,
    );
    final previewStyle = style?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (previewDisplay.isNotEmpty)
            Text(
              'Listening: $previewDisplay',
              style: previewStyle,
              textAlign: TextAlign.center,
            ),
          if (previewIndices.isNotEmpty)
            Text(
              'Preview matched: $previewMatchedDisplay',
              style: previewStyle,
              textAlign: TextAlign.center,
            ),
          if (heardDisplay.isNotEmpty)
            Text(
              'Heard: $heardDisplay',
              style: style,
              textAlign: TextAlign.center,
            ),
          Text(
            'Matched: $matchedDisplay',
            style: style,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _buildStatusMessage() {
    final status = _controller.status;
    if (_controller.isAwaitingPronunciationReview) {
      return 'Review the pronunciation feedback and tap Next to continue.';
    }
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
    if (taskKind == TrainingTaskKind.numberToWord) {
      if (status == TrainerStatus.running) {
        return 'Select the correct answer for the number.';
      }
      return 'Tap Start to begin.';
    }
    if (taskKind == TrainingTaskKind.wordToNumber) {
      if (status == TrainerStatus.running) {
        return 'Select the number matching the text.';
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

  Color _resolveFeedbackColor(ThemeData theme, TrainingFeedbackType type) {
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
      return Text(prompt, style: baseStyle, textAlign: TextAlign.center);
    }

    final matchedStyle = baseStyle.copyWith(color: theme.colorScheme.primary);
    final previewColor = theme.colorScheme.primary.withValues(alpha: 0.55);
    final previewStyle = baseStyle.copyWith(
      color: previewColor,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: previewColor,
    );
    final previewSet = _controller.previewMatchedIndices.toSet();

    final spans = <TextSpan>[];
    for (var i = 0; i < _controller.expectedTokens.length; i++) {
      final token = _controller.expectedTokens[i];
      final isMatched = _controller.matchedTokens[i];
      final isPreview = previewSet.contains(i);
      spans.add(
        TextSpan(
          text: token,
          style: isMatched
              ? matchedStyle
              : (isPreview ? previewStyle : baseStyle),
        ),
      );
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PhraseToken {
  final String text;
  final bool isWord;

  const _PhraseToken(this.text, this.isWord);
}
