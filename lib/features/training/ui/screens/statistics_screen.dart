import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/number_cards.dart';
import '../../data/progress_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/learning_language.dart';
import '../../domain/learning_strategy/learning_params.dart';
import '../../domain/study_streak_service.dart';
import '../../domain/training_item.dart';
import '../../../../core/theme/app_palette.dart';
import '../widgets/training_background.dart';
import 'training_item_type_x.dart';
import 'widgets/stats_card_surface.dart';
import 'widgets/streak_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.progressBox,
    required this.settingsBox,
    required this.language,
  });

  final Box<CardProgress> progressBox;
  final Box<String> settingsBox;
  final LearningLanguage language;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final ProgressRepository _progressRepository;
  late final SettingsRepository _settingsRepository;
  late final StudyStreakService _streakService;
  Map<TrainingItemId, CardProgress> _progressById = {};
  StudyStreakSnapshot? _streakSnapshot;
  List<TrainingItemId> _ids = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _progressRepository = ProgressRepository(widget.progressBox);
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _streakService = StudyStreakService(
      settingsRepository: _settingsRepository,
    );
    _load();
  }

  Future<void> _load() async {
    final ids = buildAllCardIds();
    final progress = await _progressRepository.loadAll(
      ids,
      language: widget.language,
    );
    final streakSnapshot = _streakService.readCurrentStreakSnapshot(
      now: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _ids = ids;
      _progressById = progress;
      _streakSnapshot = streakSnapshot;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: TrainingBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Statistics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final progressById = {
      for (final id in _ids) id: _progressById[id] ?? CardProgress.empty,
    };
    final streakSnapshot =
        _streakSnapshot ??
        _streakService.readCurrentStreakSnapshot(now: DateTime.now());

    final totalCards = _ids.length;
    final learnedCount = progressById.values.where((it) => it.learned).length;

    final totalAttempts = progressById.values.fold<int>(
      0,
      (sum, progress) => sum + progress.totalAttempts,
    );
    final totalCorrect = progressById.values.fold<int>(
      0,
      (sum, progress) => sum + progress.totalCorrect,
    );
    final accuracy = totalAttempts == 0 ? 0.0 : totalCorrect / totalAttempts;

    final weakCards = _resolveWeakCards(progressById);
    final typeRows = _resolveTypeRows(progressById);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryGrid(
            totalCards: totalCards,
            learnedCount: learnedCount,
            totalAttempts: totalAttempts,
            accuracy: accuracy,
          ),
          const SizedBox(height: 18),
          StreakCard(snapshot: streakSnapshot),
          const SizedBox(height: 18),
          _buildTypeSection(theme, typeRows),
          const SizedBox(height: 18),
          _buildWeakSection(theme, weakCards),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid({
    required int totalCards,
    required int learnedCount,
    required int totalAttempts,
    required double accuracy,
  }) {
    final theme = Theme.of(context);
    final learnedPercent = totalCards == 0 ? 0.0 : learnedCount / totalCards;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 12.0;
        const columns = 2;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _MiniStatCard(
              width: cardWidth,
              title: 'Learned',
              value: '$learnedCount / $totalCards',
              subtitle:
                  '${(learnedPercent * 100).toStringAsFixed(1)}% of all cards',
              accent: theme.colorScheme.primary,
            ),
            _MiniStatCard(
              width: cardWidth,
              title: 'Accuracy',
              value: '${(accuracy * 100).toStringAsFixed(1)}%',
              subtitle: '$totalAttempts attempts',
              accent: AppPalette.primaryBlue,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeSection(ThemeData theme, List<_TypeRow> rows) {
    return StatsCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By card type',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) {
            final coverage = row.total == 0 ? 0.0 : row.learned / row.total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 126, child: Text(row.type.label)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: coverage,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${row.learned}/${row.total}'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeakSection(ThemeData theme, List<_WeakCard> weakCards) {
    final window = LearningParams.defaults().recentAttemptsWindow;
    return StatsCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus cards',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lowest recent accuracy (last $window attempts, not learned).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (weakCards.isEmpty)
            Text('No weak cards yet.', style: theme.textTheme.bodyMedium)
          else
            ...weakCards.map((row) {
              final pct = (row.recentAccuracy * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(_cardDisplayText(row.id))),
                    Text(
                      '${row.attempts} attempts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 62,
                      child: Text(
                        '$pct%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  List<_TypeRow> _resolveTypeRows(
    Map<TrainingItemId, CardProgress> progressById,
  ) {
    final rows = <TrainingItemType, _TypeRow>{
      for (final type in TrainingItemType.values) type: _TypeRow(type),
    };
    for (final entry in progressById.entries) {
      final row = rows[entry.key.type]!;
      row.total += 1;
      if (entry.value.learned) {
        row.learned += 1;
      }
    }
    return rows.values.toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
  }

  List<_WeakCard> _resolveWeakCards(
    Map<TrainingItemId, CardProgress> progressById,
  ) {
    final window = LearningParams.defaults().recentAttemptsWindow;
    final rows = <_WeakCard>[];
    for (final entry in progressById.entries) {
      final progress = entry.value;
      if (progress.learned || progress.totalAttempts == 0) {
        continue;
      }
      rows.add(
        _WeakCard(
          id: entry.key,
          attempts: progress.totalAttempts,
          recentAccuracy: progress.recentAccuracy(windowAttempts: window),
        ),
      );
    }

    rows.sort((a, b) {
      final accDiff = a.recentAccuracy.compareTo(b.recentAccuracy);
      if (accDiff != 0) return accDiff;
      final attemptsDiff = b.attempts.compareTo(a.attempts);
      if (attemptsDiff != 0) return attemptsDiff;
      return a.id.compareTo(b.id);
    });

    if (rows.length > 12) {
      rows.removeRange(12, rows.length);
    }
    return rows;
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StatsCardSurface(
      width: width,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeRow {
  _TypeRow(this.type);

  final TrainingItemType type;
  int total = 0;
  int learned = 0;
}

class _WeakCard {
  const _WeakCard({
    required this.id,
    required this.attempts,
    required this.recentAccuracy,
  });

  final TrainingItemId id;
  final int attempts;
  final double recentAccuracy;
}

String _cardDisplayText(TrainingItemId id) {
  if (id.type == TrainingItemType.timeRandom) {
    return id.type.label;
  }
  final number = id.number;
  if (number != null) return number.toString();
  final time = id.time;
  if (time != null) return time.displayText;
  return id.storageKey;
}
