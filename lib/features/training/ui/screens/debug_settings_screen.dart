import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/learning_language.dart';
import '../../domain/language_router.dart';
import '../../domain/learning_strategy/learning_params.dart';
import '../../domain/progress_manager.dart';
import '../../domain/training_item.dart';
import '../../domain/training_task.dart';
import '../../languages/registry.dart';
import '../widgets/slider_peek.dart';

class DebugSettingsScreen extends StatefulWidget {
  const DebugSettingsScreen({
    super.key,
    required this.settingsBox,
    required this.progressBox,
    this.onProgressChanged,
  });

  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;
  final VoidCallback? onProgressChanged;

  @override
  State<DebugSettingsScreen> createState() => _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends State<DebugSettingsScreen>
    with SingleTickerProviderStateMixin {
  static const List<TrainingItemType> _simulationItemTypes = <TrainingItemType>[
    TrainingItemType.digits,
    TrainingItemType.base,
  ];
  static final int _almostLearnedCorrectAttempts =
      (LearningParams.defaults().minAttemptsToLearn - 1).clamp(1, 1000).toInt();

  late final SettingsRepository _settingsRepository;
  late final ProgressRepository _progressRepository;
  late LearningLanguage _language;
  LearningMethod? _debugForcedLearningMethod;
  TrainingItemType? _debugForcedItemType;
  TrainingItemType _debugSimulationItemType = TrainingItemType.digits;
  int _sliderPeekClockPosition = 0;
  bool _debugMarkingAlmostLearned = false;
  bool _queueLoading = false;
  bool _sliderPeekLoading = false;
  bool _sliderPeekRunning = false;
  String? _queuePreview;
  final math.Random _random = math.Random();

  late final AnimationController _sliderPeekController;
  List<SliderPeekAsset> _sliderPeekAssets = const [];
  SliderPeekAsset? _activeSliderPeekAsset;
  Animation<Offset>? _activeSliderPeekAnimation;
  int? _activeSliderPeekClockPosition;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _progressRepository = ProgressRepository(widget.progressBox);
    _language = _settingsRepository.readLearningLanguage();
    _debugForcedLearningMethod = _settingsRepository
        .readDebugForcedLearningMethod();
    _debugForcedItemType = _settingsRepository.readDebugForcedItemType();
    _sliderPeekController = AnimationController(
      vsync: this,
      duration: sliderPeekMoveDuration,
    );
    unawaited(_loadSliderPeekAssets());
  }

  @override
  void dispose() {
    _sliderPeekController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<int> _availableSliderPeekClockPositions() {
    final positions =
        _sliderPeekAssets.map((asset) => asset.clockPosition).toSet().toList()
          ..sort();
    return positions;
  }

  String _availableSliderPeekClockPositionsLabel() {
    final positions = _availableSliderPeekClockPositions();
    if (positions.isEmpty) {
      return 'none';
    }
    return positions.join(', ');
  }

  Future<void> _updateDebugForcedLearningMethod(LearningMethod? method) async {
    setState(() {
      _debugForcedLearningMethod = method;
    });
    await _settingsRepository.setDebugForcedLearningMethod(method);
  }

  Future<void> _updateDebugForcedItemType(TrainingItemType? type) async {
    setState(() {
      _debugForcedItemType = type;
    });
    await _settingsRepository.setDebugForcedItemType(type);
  }

  void _updateDebugSimulationItemType(TrainingItemType? type) {
    if (type == null) return;
    setState(() {
      _debugSimulationItemType = type;
    });
  }

  void _updateSliderPeekClockPosition(int? value) {
    if (value == null) return;
    setState(() {
      _sliderPeekClockPosition = value;
    });
  }

  Future<void> _loadSliderPeekAssets() async {
    setState(() {
      _sliderPeekLoading = true;
    });
    try {
      final assets = await loadSliderPeekAssets();
      if (!mounted) return;
      setState(() {
        _sliderPeekAssets = assets;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sliderPeekAssets = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _sliderPeekLoading = false;
        });
      }
    }
  }

  Future<void> _showSliderPeekPreview() async {
    if (_sliderPeekRunning || _sliderPeekLoading) return;
    if (_sliderPeekAssets.isEmpty) {
      _showSnack('No slider images found in assets/images/sliders/.');
      return;
    }

    final clockPosition = _sliderPeekClockPosition;
    final selected = pickRandomSliderPeekAssetForClockPosition(
      assets: _sliderPeekAssets,
      clockPosition: clockPosition,
      random: _random,
    );
    if (selected == null) {
      _showSnack(
        'No slider image found for position $clockPosition. '
        'Available positions: ${_availableSliderPeekClockPositionsLabel()}.',
      );
      return;
    }

    final animation = createSliderPeekAnimation(
      controller: _sliderPeekController,
      clockPosition: clockPosition,
    );

    setState(() {
      _activeSliderPeekAsset = selected;
      _activeSliderPeekClockPosition = selected.clockPosition;
      _activeSliderPeekAnimation = animation;
      _sliderPeekRunning = true;
    });

    try {
      await playSliderPeekSequence(
        controller: _sliderPeekController,
        holdDuration: sliderPeekHoldDuration,
        shouldContinue: () => mounted,
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeSliderPeekAsset = null;
          _activeSliderPeekClockPosition = null;
          _activeSliderPeekAnimation = null;
          _sliderPeekRunning = false;
        });
      }
    }
  }

  Future<void> _simulateAlmostLearnedCard() async {
    if (_debugMarkingAlmostLearned) return;
    setState(() {
      _debugMarkingAlmostLearned = true;
    });
    try {
      final snapshot = await _loadQueueSnapshot();
      final candidates =
          snapshot.all
              .where((id) => id.type == _debugSimulationItemType)
              .toList()
            ..sort();
      if (candidates.isEmpty) {
        _showSnack(
          'No cards found for ${_itemTypeLabel(_debugSimulationItemType)}.',
        );
        return;
      }

      final selected = _pickSimulationTarget(candidates, snapshot);
      final now = DateTime.now().millisecondsSinceEpoch;
      final simulated = CardProgress(
        learned: false,
        clusters: <CardCluster>[
          CardCluster(
            lastAnswerAt: now,
            correctCount: _almostLearnedCorrectAttempts,
            wrongCount: 0,
            skippedCount: 0,
          ),
        ],
        learnedAt: 0,
        firstAttemptAt: now,
      );
      await _progressRepository.save(selected, simulated, language: _language);
      widget.onProgressChanged?.call();
      _showSnack('Simulated almost learned card: ${_formatQueueId(selected)}.');
    } catch (error) {
      _showSnack('Failed to simulate almost learned card: $error');
    } finally {
      if (mounted) {
        setState(() {
          _debugMarkingAlmostLearned = false;
        });
      }
    }
  }

  TrainingItemId _pickSimulationTarget(
    List<TrainingItemId> candidates,
    LearningQueueDebugSnapshot snapshot,
  ) {
    for (final id in candidates) {
      final progress = snapshot.progressById[id] ?? CardProgress.empty;
      if (!progress.learned) {
        return id;
      }
    }
    return candidates.first;
  }

  String _itemTypeLabel(TrainingItemType type) {
    switch (type) {
      case TrainingItemType.digits:
        return 'Digits';
      case TrainingItemType.base:
        return 'Base';
      case TrainingItemType.hundreds:
        return 'Hundreds';
      case TrainingItemType.thousands:
        return 'Thousands';
      case TrainingItemType.timeExact:
        return 'Time (exact)';
      case TrainingItemType.timeQuarter:
        return 'Time (quarter)';
      case TrainingItemType.timeHalf:
        return 'Time (half)';
      case TrainingItemType.timeRandom:
        return 'Time (random)';
    }
  }

  String _formatQueueId(TrainingItemId id) {
    if (id.time != null) {
      return '${id.type.name}:${id.time!.displayText}';
    }
    final number = id.number;
    final suffix = number != null ? number.toString() : '*';
    return '${id.type.name}:$suffix';
  }

  CardProgress _progressFor(
    LearningQueueDebugSnapshot snapshot,
    TrainingItemId id,
  ) {
    return snapshot.progressById[id] ?? CardProgress.empty;
  }

  int _totalWrong(CardProgress progress) {
    return progress.totalWrong;
  }

  int _sumAttempts(
    Iterable<TrainingItemId> ids,
    LearningQueueDebugSnapshot snapshot,
  ) {
    var total = 0;
    for (final id in ids) {
      total += _progressFor(snapshot, id).totalAttempts;
    }
    return total;
  }

  int _sumCorrect(
    Iterable<TrainingItemId> ids,
    LearningQueueDebugSnapshot snapshot,
  ) {
    var total = 0;
    for (final id in ids) {
      total += _progressFor(snapshot, id).totalCorrect;
    }
    return total;
  }

  int _sumWrong(
    Iterable<TrainingItemId> ids,
    LearningQueueDebugSnapshot snapshot,
  ) {
    var total = 0;
    for (final id in ids) {
      total += _totalWrong(_progressFor(snapshot, id));
    }
    return total;
  }

  int _sumSkipped(
    Iterable<TrainingItemId> ids,
    LearningQueueDebugSnapshot snapshot,
  ) {
    var total = 0;
    for (final id in ids) {
      total += _progressFor(snapshot, id).totalSkipped;
    }
    return total;
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatQueueCardLine(
    TrainingItemId id,
    LearningQueueDebugSnapshot snapshot,
  ) {
    final progress = _progressFor(snapshot, id);
    final lastAnswerAt = progress.lastCluster?.lastAnswerAt ?? 0;
    final lastAnswerText = lastAnswerAt <= 0
        ? '-'
        : _formatDateTime(DateTime.fromMillisecondsSinceEpoch(lastAnswerAt));
    final status = progress.learned ? 'learned' : 'learning';
    final correct = progress.totalCorrect;
    final wrong = _totalWrong(progress);
    final skipped = progress.totalSkipped;
    final attempts = progress.totalAttempts;
    final accuracy = attempts == 0 ? 0.0 : correct / attempts;
    final weight = snapshot.weightById[id] ?? 0;
    return '${_formatQueueId(id)} | weight: ${weight.toStringAsFixed(3)} '
        '| $status | acc: ${(accuracy * 100).toStringAsFixed(1)}% '
        '| c/w/s: $correct/$wrong/$skipped | attempts: $attempts '
        '| last: $lastAnswerText';
  }

  String _formatQueuePreview(LearningQueueDebugSnapshot snapshot) {
    final language = snapshot.language ?? _language;
    final languageLabel = LanguageRegistry.of(language).label;
    final totalAttempts = _sumAttempts(snapshot.all, snapshot);
    final totalCorrect = _sumCorrect(snapshot.all, snapshot);
    final totalWrong = _sumWrong(snapshot.all, snapshot);
    final totalSkipped = _sumSkipped(snapshot.all, snapshot);
    final prioritizedHead = snapshot.prioritized
        .take(8)
        .map((id) => _formatQueueId(id))
        .join(', ');
    final prioritizedSuffix = snapshot.prioritized.length > 8 ? ', ...' : '';
    final attemptsRemaining =
        (snapshot.dailyAttemptLimit - snapshot.dailyAttemptsToday).clamp(
          0,
          snapshot.dailyAttemptLimit,
        );
    final newCardsRemaining =
        (snapshot.dailyNewCardsLimit - snapshot.dailyNewCardsToday).clamp(
          0,
          snapshot.dailyNewCardsLimit,
        );
    return [
      'Language: $languageLabel',
      'Daily attempts: ${snapshot.dailyAttemptsToday}/${snapshot.dailyAttemptLimit} '
          '(remaining $attemptsRemaining)',
      'Daily new cards: ${snapshot.dailyNewCardsToday}/${snapshot.dailyNewCardsLimit} '
          '(remaining $newCardsRemaining)',
      'Top priority: ${prioritizedHead.isEmpty ? 'empty' : '$prioritizedHead$prioritizedSuffix'}',
      'Answers: $totalAttempts (correct $totalCorrect, '
          'wrong $totalWrong, skipped $totalSkipped)',
    ].join('\n');
  }

  String _formatQueueClipboard(LearningQueueDebugSnapshot snapshot) {
    final language = snapshot.language ?? _language;
    final languageLabel = LanguageRegistry.of(language).label;
    final now = DateTime.now();
    final totalAttempts = _sumAttempts(snapshot.all, snapshot);
    final totalCorrect = _sumCorrect(snapshot.all, snapshot);
    final totalWrong = _sumWrong(snapshot.all, snapshot);
    final totalSkipped = _sumSkipped(snapshot.all, snapshot);
    const priorityCopyLimit = 500;
    final buffer = StringBuffer()
      ..writeln('Generated at: ${_formatDateTime(now)}')
      ..writeln('Language: $languageLabel')
      ..writeln('Total cards: ${snapshot.all.length}')
      ..writeln(
        'Daily attempts: ${snapshot.dailyAttemptsToday}/${snapshot.dailyAttemptLimit}',
      )
      ..writeln(
        'Daily new cards: ${snapshot.dailyNewCardsToday}/${snapshot.dailyNewCardsLimit}',
      )
      ..writeln(
        'Answers total: $totalAttempts '
        '(correct: $totalCorrect, wrong: $totalWrong, skipped: $totalSkipped)',
      )
      ..writeln('Priority list (${snapshot.prioritized.length}):');
    final prioritizedItems = snapshot.prioritized
        .take(priorityCopyLimit)
        .toList();
    for (var i = 0; i < prioritizedItems.length; i++) {
      buffer.writeln(
        '  ${i + 1}. '
        '${_formatQueueCardLine(prioritizedItems[i], snapshot)}',
      );
    }
    final remaining = snapshot.prioritized.length - prioritizedItems.length;
    if (remaining > 0) {
      buffer.writeln('  ... +$remaining more');
    }
    return buffer.toString();
  }

  Future<LearningQueueDebugSnapshot> _loadQueueSnapshot() async {
    final languageRouter = LanguageRouter(
      settingsRepository: _settingsRepository,
    );
    final language = languageRouter.currentLanguage;
    final manager = ProgressManager(
      progressRepository: _progressRepository,
      languageRouter: languageRouter,
    );
    await manager.loadProgress(language);
    return manager.debugQueueSnapshot();
  }

  Future<void> _copyQueueToClipboard() async {
    if (_queueLoading) return;
    setState(() {
      _queueLoading = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final snapshot = await _loadQueueSnapshot();
      final preview = _formatQueuePreview(snapshot);
      final clipboardText = _formatQueueClipboard(snapshot);
      await Clipboard.setData(ClipboardData(text: clipboardText));
      if (!mounted) return;
      setState(() {
        _queuePreview = preview;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Card priorities copied to clipboard.')),
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to copy queue: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _queueLoading = false;
        });
      }
    }
  }

  Widget _buildSliderPeekOverlay() {
    final asset = _activeSliderPeekAsset;
    final animation = _activeSliderPeekAnimation;
    final clockPosition = _activeSliderPeekClockPosition;
    if (asset == null || animation == null || clockPosition == null) {
      return const SizedBox.shrink();
    }
    return SliderPeekOverlay(
      assetPath: asset.assetPath,
      clockPosition: clockPosition,
      animation: animation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debug')),
        body: const Center(
          child: Text('Debug menu is available only in debug mode.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<TrainingItemType?>(
                initialValue: _debugForcedItemType,
                onChanged: _updateDebugForcedItemType,
                items: [
                  const DropdownMenuItem<TrainingItemType?>(
                    value: null,
                    child: Text('No forced card type'),
                  ),
                  ...TrainingItemType.values.map(
                    (type) => DropdownMenuItem<TrainingItemType?>(
                      value: type,
                      child: Text(_itemTypeLabel(type)),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Force card type',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Filters the training pool to only the selected card type.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LearningMethod?>(
                initialValue: _debugForcedLearningMethod,
                onChanged: _updateDebugForcedLearningMethod,
                items: [
                  const DropdownMenuItem<LearningMethod?>(
                    value: null,
                    child: Text('No forced learning method'),
                  ),
                  ...LearningMethod.values.map(
                    (method) => DropdownMenuItem<LearningMethod?>(
                      value: method,
                      child: Text(method.label),
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Force learning method',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Forces the trainer to use only the selected learning method.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sliding animation',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _sliderPeekClockPosition,
                onChanged: _updateSliderPeekClockPosition,
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem<int>(
                    value: index,
                    child: Text(index.toString()),
                  ),
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Clock position (0-11)',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: (_sliderPeekRunning || _sliderPeekLoading)
                    ? null
                    : _showSliderPeekPreview,
                icon: (_sliderPeekRunning || _sliderPeekLoading)
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      )
                    : const Icon(Icons.swipe),
                label: Text(
                  _sliderPeekLoading
                      ? 'Loading images...'
                      : _sliderPeekRunning
                      ? 'Playing...'
                      : 'Show sliding animation',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Uses the same slide sequence as training. Position sets entry side '
                '(0 top, 3 right, 6 bottom, 9 left). Assets found: ${_sliderPeekAssets.length}. '
                'Available positions: ${_availableSliderPeekClockPositionsLabel()}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Simulation',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TrainingItemType>(
                initialValue: _debugSimulationItemType,
                onChanged: _updateDebugSimulationItemType,
                items: _simulationItemTypes
                    .map(
                      (type) => DropdownMenuItem<TrainingItemType>(
                        value: type,
                        child: Text(_itemTypeLabel(type)),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Card class',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _debugMarkingAlmostLearned
                    ? null
                    : _simulateAlmostLearnedCard,
                icon: _debugMarkingAlmostLearned
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      )
                    : const Icon(Icons.school),
                label: Text(
                  _debugMarkingAlmostLearned
                      ? 'Updating...'
                      : 'Simulate almost learned card',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sets one card in selected class to $_almostLearnedCorrectAttempts correct attempts (not learned yet).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _queueLoading ? null : _copyQueueToClipboard,
                icon: _queueLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      )
                    : const Icon(Icons.copy_all),
                label: Text(
                  _queueLoading ? 'Copying...' : 'Copy card priorities',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Copies current probabilistic priority list to clipboard.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_queuePreview != null) ...[
                const SizedBox(height: 6),
                Text(
                  _queuePreview!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          _buildSliderPeekOverlay(),
        ],
      ),
    );
  }
}
