import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../app_definition.dart';
import '../exercise_models.dart';
import '../progress_repository.dart';
import '../settings_repository.dart';
import '../trainer_controller.dart';
import '../trainer_state.dart';
import '../training/data/card_progress.dart';
import 'widgets/training_background.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    super.key,
    required this.appDefinition,
    required this.settingsBox,
    required this.progressBox,
  });

  final TrainingAppDefinition appDefinition;
  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late final SettingsRepository _settingsRepository;
  late final ProgressRepository _progressRepository;
  late final TrainerController _controller;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository.forApp(
      widget.settingsBox,
      widget.appDefinition.config,
    );
    _progressRepository = ProgressRepository(widget.progressBox);
    _controller = TrainerController(
      appDefinition: widget.appDefinition,
      settingsRepository: _settingsRepository,
      progressRepository: _progressRepository,
    );
    unawaited(_initializeAndStart());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeAndStart() async {
    await _controller.initialize();
    if (!mounted) {
      return;
    }
    await _controller.startTraining();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final theme = Theme.of(context);
        return Scaffold(
          body: TrainingBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _handleStopTraining,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Text(
                            _controller.currentMode?.label ?? 'Training',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (state.errorMessage != null) ...[
                      Card(
                        color: theme.colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(state.errorMessage!),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.feedback != null) ...[
                      _FeedbackBadge(feedback: state.feedback!),
                      const SizedBox(height: 12),
                    ],
                    if (state.celebration != null) ...[
                      _CelebrationCard(
                        celebration: state.celebration!,
                        onContinue: _controller.continueAfterCelebration,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Expanded(child: _buildBody(state)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(TrainingState state) {
    final sessionStats = state.sessionStats;
    if (sessionStats != null) {
      return _SessionSummary(
        stats: sessionStats,
        onContinue: _controller.continueSession,
        onStop: _handleStopTraining,
      );
    }

    final task = state.currentTask;
    if (task == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (task is SpeakState) {
      return _SpeakTaskView(state: task, onRetry: _controller.retryInitSpeech);
    }
    if (task is ChoiceState) {
      return _ChoiceTaskView(state: task, onSelect: _controller.selectOption);
    }
    if (task is ListenAndChooseState) {
      return _ListenTaskView(
        state: task,
        onReplay: _controller.repeatListeningPrompt,
        onSelect: _controller.selectOption,
      );
    }
    if (task is ReviewPronunciationState) {
      return _ReviewTaskView(
        state: task,
        onStartRecording: _controller.startPronunciationRecording,
        onStopRecording: _controller.stopPronunciationRecording,
        onCancelRecording: _controller.cancelPronunciationRecording,
        onSendRecording: _controller.sendPronunciationRecording,
        onCompleteReview: _controller.completePronunciationReview,
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleStopTraining() async {
    await _controller.stopTraining();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _FeedbackBadge extends StatelessWidget {
  const _FeedbackBadge({required this.feedback});

  final TrainingFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (feedback.outcome) {
      TrainingOutcome.correct => ('Correct', Colors.green.shade700),
      TrainingOutcome.wrong => ('Wrong', Colors.red.shade700),
      TrainingOutcome.timeout => ('Timeout', Colors.orange.shade700),
      TrainingOutcome.skipped => ('Skipped', Colors.blueGrey.shade700),
    };
    return Align(
      alignment: Alignment.center,
      child: Chip(
        label: Text(label),
        backgroundColor: color.withValues(alpha: 0.15),
        labelStyle: theme.textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.celebration, required this.onContinue});

  final TrainingCelebration celebration;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learned',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(celebration.masteredText),
            Text('${celebration.modeLabel} • ${celebration.categoryLabel}'),
            const SizedBox(height: 10),
            FilledButton(onPressed: onContinue, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.stats,
    required this.onContinue,
    required this.onStop,
  });

  final SessionStats stats;
  final Future<void> Function() onContinue;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Session Complete',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text('Cards completed: ${stats.cardsCompleted}'),
              Text('Sessions today: ${stats.sessionsCompletedToday}'),
              Text('Cards today: ${stats.cardsCompletedToday}'),
              Text('Duration: ${stats.duration.inMinutes} min'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed: onStop,
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: onContinue,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeakTaskView extends StatelessWidget {
  const _SpeakTaskView({required this.state, required this.onRetry});

  final SpeakState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.family.label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              state.displayText,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            _TimerText(timer: state.timer),
            if (state.hintText != null) ...[
              const SizedBox(height: 12),
              Text('Hint: ${state.hintText}'),
            ],
            const SizedBox(height: 12),
            if (state.lastHeardText != null)
              Text('Heard: ${state.lastHeardText}'),
            if (!state.speechReady) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry speech init'),
              ),
            ],
            const Spacer(),
            Text(
              state.isListening ? 'Listening...' : 'Waiting...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTaskView extends StatelessWidget {
  const _ChoiceTaskView({required this.state, required this.onSelect});

  final ChoiceState state;
  final Future<void> Function(String option) onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.displayText,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _TimerText(timer: state.timer),
            const SizedBox(height: 20),
            for (final option in state.options) ...[
              FilledButton.tonal(
                onPressed: () => onSelect(option),
                child: Text(option),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListenTaskView extends StatelessWidget {
  const _ListenTaskView({
    required this.state,
    required this.onReplay,
    required this.onSelect,
  });

  final ListenAndChooseState state;
  final Future<void> Function() onReplay;
  final Future<void> Function(String option) onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.displayText,
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _TimerText(timer: state.timer),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: state.isPromptPlaying ? null : onReplay,
              icon: const Icon(Icons.volume_up),
              label: Text(state.isPromptPlaying ? 'Playing...' : 'Replay'),
            ),
            const SizedBox(height: 20),
            for (final option in state.options) ...[
              FilledButton.tonal(
                onPressed: () => onSelect(option),
                child: Text(option),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewTaskView extends StatelessWidget {
  const _ReviewTaskView({
    required this.state,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onSendRecording,
    required this.onCompleteReview,
  });

  final ReviewPronunciationState state;
  final Future<void> Function() onStartRecording;
  final Future<void> Function() onStopRecording;
  final Future<void> Function() onCancelRecording;
  final Future<void> Function() onSendRecording;
  final Future<void> Function() onCompleteReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.displayText,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            switch (state.flow) {
              ReviewFlow.waiting => FilledButton(
                onPressed: onStartRecording,
                child: const Text('Start recording'),
              ),
              ReviewFlow.recording => FilledButton(
                onPressed: onStopRecording,
                child: const Text('Stop recording'),
              ),
              ReviewFlow.recorded => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: onSendRecording,
                    child: const Text('Send for review'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: onCancelRecording,
                    child: const Text('Record again'),
                  ),
                ],
              ),
              ReviewFlow.sending => const Center(
                child: CircularProgressIndicator(),
              ),
              ReviewFlow.reviewing => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Heard: ${state.result?.displayText ?? '-'}'),
                  Text(
                    'Score: ${state.result?.best?.pronScore.toStringAsFixed(1) ?? '-'}',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onCompleteReview,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _TimerText extends StatelessWidget {
  const _TimerText({required this.timer});

  final TimerState timer;

  @override
  Widget build(BuildContext context) {
    final seconds = timer.remaining.inSeconds.toString().padLeft(2, '0');
    return Text('Time: $seconds s');
  }
}
