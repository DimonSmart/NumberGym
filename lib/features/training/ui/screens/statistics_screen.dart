import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/number_cards.dart';
import '../../data/progress_repository.dart';
import '../../domain/learning_strategy/learning_params.dart';
import '../../domain/learning_language.dart';
import '../../domain/training_item.dart';
import '../widgets/training_background.dart';

class StatisticsScreen extends StatefulWidget {
  final Box<CardProgress> progressBox;
  final LearningLanguage language;

  const StatisticsScreen({
    super.key,
    required this.progressBox,
    required this.language,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const int _learnedStreakTarget = 10;
  late final ProgressRepository _progressRepository;
  Map<TrainingItemId, CardProgress> _progressById = {};
  List<TrainingItemId> _gridIds = [];
  bool _loading = true;
  int _chartDays = 7;

  @override
  void initState() {
    super.initState();
    _progressRepository = ProgressRepository(widget.progressBox);
    _load();
  }

  Future<void> _load() async {
    final ids = buildAllCardIds();
    final progress = await _progressRepository.loadAll(
      ids,
      language: widget.language,
    );
    
    if (!mounted) return;
    setState(() {
      _gridIds = ids;
      _progressById = progress;
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                    const Spacer(),
                    Text(
                      '${_gridIds.isNotEmpty ? _gridIds.length : 0} items',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
    final gridProgress = {
      for (final id in _gridIds) id: _progressById[id] ?? CardProgress.empty,
    };
    final successThreshold =
        LearningParams.defaults().clusterSuccessAccuracy;

    final totalCards = _gridIds.length;
    final totalAttempts = _progressById.values.fold<int>(
      0,
      (sum, progress) => sum + progress.totalAttempts,
    );
    final totalCorrect = _progressById.values.fold<int>(
      0,
      (sum, progress) => sum + progress.totalCorrect,
    );
    final accuracy = totalAttempts == 0 ? 0.0 : totalCorrect / totalAttempts;
    final learnedCount =
        _progressById.values.where((progress) => progress.learned).length;
    final startedCount = _progressById.values
        .where((progress) => progress.totalAttempts > 0)
        .length;
    final inProgressCount = math.max(0, startedCount - learnedCount);
    final notStartedCount = math.max(0, totalCards - startedCount);
    final remainingCount = math.max(0, totalCards - learnedCount);

    final coverage = _CoverageStats(
      total: totalCards,
      learned: learnedCount,
      inProgress: inProgressCount,
      notStarted: notStartedCount,
    );
    final typeStats = _resolveTypeStats(gridProgress);
    final idsByType = _groupIdsByType(_gridIds);
    final dailyStats = _buildDailyStats(gridProgress, _chartDays);
    final forecast = _buildForecastStats(
      remaining: remainingCount,
      learnedCount: learnedCount,
      totalAttempts: totalAttempts,
      dailyStats: dailyStats,
    );
    final nextDueInfo = _resolveNextDue(gridProgress);

    final hotIds = _resolveHotIds(gridProgress);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(
            theme,
            totalAttempts: totalAttempts,
            totalCorrect: totalCorrect,
            accuracy: accuracy,
            coverage: coverage,
            forecast: forecast,
            nextDueInfo: nextDueInfo,
          ),
          const SizedBox(height: 24),
          _buildActivitySection(theme, dailyStats),
          const SizedBox(height: 24),
          _buildTypeSections(
            theme,
            typeStats,
            idsByType,
            gridProgress,
            hotIds,
            successThreshold,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    ThemeData theme, {
    required int totalAttempts,
    required int totalCorrect,
    required double accuracy,
    required _CoverageStats coverage,
    required _ForecastStats forecast,
    required _NextDueInfo nextDueInfo,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = constraints.maxWidth;
        final columns = width >= 980
            ? 4
            : width >= 720
                ? 3
                : 2;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _StatCard(
              width: cardWidth,
              title: 'Total attempts',
              value: totalAttempts.toString(),
              icon: Icons.auto_graph,
              accent: theme.colorScheme.primary,
            ),
            _StatCard(
              width: cardWidth,
              title: 'Accuracy',
              value: '${(accuracy * 100).toStringAsFixed(1)}%',
              subtitle: totalAttempts == 0
                  ? 'No attempts yet'
                  : '$totalCorrect / $totalAttempts',
              icon: Icons.insights,
              accent: theme.colorScheme.tertiary,
            ),
            _CoverageCard(
              width: cardWidth,
              coverage: coverage,
            ),
            _InsightCard(
              width: cardWidth,
              forecast: forecast,
              nextDueInfo: nextDueInfo,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivitySection(
    ThemeData theme,
    List<_DailyStats> dailyStats,
  ) {
    final totalAttempts = dailyStats.fold<int>(
      0,
      (sum, stat) => sum + stat.attempts,
    );
    final totalCorrect = dailyStats.fold<int>(
      0,
      (sum, stat) => sum + stat.correct,
    );
    final averageAttempts =
        dailyStats.isEmpty ? 0.0 : totalAttempts / dailyStats.length;
    final windowAccuracy =
        totalAttempts == 0 ? 0.0 : totalCorrect / totalAttempts;

    final attemptsValues = [
      for (final stat in dailyStats) stat.attempts.toDouble(),
    ];
    final accuracyValues = [
      for (final stat in dailyStats) stat.accuracy,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent activity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _buildWindowChip(theme, 7),
            const SizedBox(width: 8),
            _buildWindowChip(theme, 14),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final width = constraints.maxWidth;
            final columns = width >= 900 ? 2 : 1;
            final cardWidth = columns == 1
                ? width
                : (width - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _MiniChartCard(
                  width: cardWidth,
                  title: 'Attempts / day',
                  value:
                      '${averageAttempts.toStringAsFixed(1)} avg',
                  subtitle: '$totalAttempts attempts',
                  accent: theme.colorScheme.primary,
                  values: attemptsValues,
                ),
                _MiniChartCard(
                  width: cardWidth,
                  title: 'Accuracy / day',
                  value: '${(windowAccuracy * 100).toStringAsFixed(1)}%',
                  subtitle: totalAttempts == 0
                      ? 'No attempts yet'
                      : '$totalCorrect / $totalAttempts',
                  accent: theme.colorScheme.tertiary,
                  values: accuracyValues,
                  minY: 0,
                  maxY: 1,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWindowChip(ThemeData theme, int days) {
    return ChoiceChip(
      label: Text('${days}d'),
      selected: _chartDays == days,
      onSelected: (selected) {
        if (!selected || _chartDays == days) return;
        setState(() => _chartDays = days);
      },
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTypeSections(
    ThemeData theme,
    List<_TypeStats> typeStats,
    Map<TrainingItemType, List<TrainingItemId>> idsByType,
    Map<TrainingItemId, CardProgress> progressById,
    Set<TrainingItemId> hotIds,
    double successThreshold,
  ) {
    final showLegend = typeStats.any((stats) {
      final ids = idsByType[stats.type] ?? const <TrainingItemId>[];
      return _shouldShowTypeStreak(stats.type, ids.length);
    });
    final sections = <Widget>[];
    for (var i = 0; i < typeStats.length; i += 1) {
      final stats = typeStats[i];
      final ids = idsByType[stats.type] ?? const <TrainingItemId>[];
      final showStreak = _shouldShowTypeStreak(stats.type, ids.length);
      final streakGrid = showStreak
          ? _buildGrid(
              theme,
              ids,
              progressById,
              hotIds,
              successThreshold,
              columns: _gridColumnsForType(stats.type, ids.length),
            )
          : null;
      sections.add(
        _TypeCard(
          stats: stats,
          streakGrid: streakGrid,
        ),
      );
      if (i != typeStats.length - 1) {
        sections.add(const SizedBox(height: 18));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By card type',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (showLegend) ...[
          Text(
            'Progress legend',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Color shows learning progress; number below is the current successful cluster run.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _buildLegend(theme),
          const SizedBox(height: 16),
        ],
        ...sections,
      ],
    );
  }

  Widget _buildLegend(ThemeData theme) {
    final scheme = theme.colorScheme;
    final notStartedColor = _notStartedColor(scheme);
    final startedColor = _startedColor(scheme);
    final learnedColor = _learnedColor(scheme);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendSwatch(
          color: notStartedColor,
          label: 'Not started',
        ),
        _LegendSwatch(
          color: startedColor,
          label: 'Just started',
        ),
        _LegendSwatch(
          gradient: LinearGradient(
            colors: [startedColor, learnedColor],
          ),
          label: 'In progress',
        ),
        _LegendSwatch(
          color: learnedColor,
          label: 'Learned',
        ),
        _LegendSwatch(
          color: theme.colorScheme.surface,
          borderColor: theme.colorScheme.error,
          borderWidth: 2,
          label: 'Needs attention (many attempts)',
        ),
      ],
    );
  }

  Widget _buildGrid(
    ThemeData theme,
    List<TrainingItemId> gridIds,
    Map<TrainingItemId, CardProgress> progressById,
    Set<TrainingItemId> hotIds,
    double successThreshold,
    {int columns = 10}
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 6.0;
        final width = constraints.maxWidth;
        final innerWidth = width > 24 ? width - 24 : width;
        final cellSize = (innerWidth - spacing * (columns - 1)) / columns;
        final numberFontSize = (cellSize * 0.42).clamp(10.0, 18.0).toDouble();
        final streakFontSize = (cellSize * 0.2).clamp(8.0, 12.0).toDouble();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: GridView.builder(
            itemCount: gridIds.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
            ),
            itemBuilder: (context, index) {
              final id = gridIds[index];
              final progress = progressById[id] ?? CardProgress.empty;
              final streak =
                  _clusterSuccessStreak(progress, successThreshold);
              final baseColor =
                  _progressColor(theme.colorScheme, progress, streak);
              final isHot = hotIds.contains(id);
              final displayText = _cardDisplayText(id);
              final borderColor = isHot
                  ? theme.colorScheme.error
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
              final borderWidth = isHot ? 2.0 : 1.0;
              final textColor =
                  ThemeData.estimateBrightnessForColor(baseColor) ==
                          Brightness.dark
                      ? Colors.white
                      : theme.colorScheme.onSurface;

              return GestureDetector(
                onTap: () => _showCardDetails(
                  context,
                  id,
                  progress,
                  successThreshold,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: borderWidth),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayText,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: numberFontSize,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'x$streak',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: streakFontSize,
                              fontWeight: FontWeight.w600,
                              color: textColor.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showCardDetails(
    BuildContext context,
    TrainingItemId id,
    CardProgress progress,
    double successThreshold,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _buildCardDetailsSheet(
          context,
          id,
          progress,
          successThreshold,
        );
      },
    );
  }

  Widget _buildCardDetailsSheet(
    BuildContext context,
    TrainingItemId id,
    CardProgress progress,
    double successThreshold,
  ) {
    final theme = Theme.of(context);
    final totalAttempts = progress.totalAttempts;
    final accuracy =
        totalAttempts == 0 ? 0.0 : progress.totalCorrect / totalAttempts;
    final streak = _clusterSuccessStreak(progress, successThreshold);
    final statusLabel = progress.learned
        ? 'Learned'
        : totalAttempts == 0
            ? 'Not started'
            : 'In progress';
    final nextDueLabel = _formatNextDue(progress.nextDue);
    final typeLabel = _typeLabel(id.type);
    final typeRange = _typeRange(id.type);
    final displayText = _cardDisplayText(id);
    final clusters = progress.clusters.reversed.toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  displayText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                _Tag(
                  label: '$typeLabel $typeRange',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              statusLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DetailPill(
                  label: 'Clusters',
                  value: progress.clusters.length.toString(),
                ),
                _DetailPill(
                  label: 'Attempts',
                  value: totalAttempts.toString(),
                ),
                _DetailPill(
                  label: 'Correct',
                  value: progress.totalCorrect.toString(),
                ),
                _DetailPill(
                  label: 'Accuracy',
                  value: '${(accuracy * 100).toStringAsFixed(1)}%',
                ),
                _DetailPill(
                  label: 'Run',
                  value: 'x$streak',
                ),
                _DetailPill(
                  label: 'Next due',
                  value: nextDueLabel,
                ),
                _DetailPill(
                  label: 'Interval',
                  value: '${progress.intervalDays.toStringAsFixed(1)}d',
                ),
                _DetailPill(
                  label: 'Ease',
                  value: progress.ease.toStringAsFixed(2),
                ),
                if (progress.learnedAt > 0)
                  _DetailPill(
                    label: 'Learned at',
                    value: _formatDateTime(
                      DateTime.fromMillisecondsSinceEpoch(progress.learnedAt),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Recent clusters',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (clusters.isEmpty)
              Text(
                'No attempts yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...clusters.map((cluster) {
                final isSuccess = _isClusterSuccess(
                  cluster,
                  successThreshold,
                );
                final timestamp = cluster.lastAnswerAt == 0
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        cluster.lastAnswerAt,
                      );
                final dateLabel =
                    timestamp == null ? 'Legacy' : _formatDateTime(timestamp);
                return _ClusterRow(
                  dateLabel: dateLabel,
                  cluster: cluster,
                  isSuccess: isSuccess,
                );
              }),
          ],
        );
      },
    );
  }

  List<_TypeStats> _resolveTypeStats(
    Map<TrainingItemId, CardProgress> progressById,
  ) {
    final statsByType = <TrainingItemType, _TypeStats>{
      for (final type in TrainingItemType.values)
        type: _TypeStats(type: type),
    };
    for (final entry in progressById.entries) {
      final stats = statsByType[entry.key.type]!;
      final progress = entry.value;
      stats.total += 1;
      if (progress.totalAttempts > 0) {
        stats.started += 1;
      }
      if (progress.learned) {
        stats.learned += 1;
      }
      stats.attempts += progress.totalAttempts;
      stats.correct += progress.totalCorrect;
      stats.sessions += progress.clusters.length;
    }
    final items = statsByType.values.toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
    return items;
  }

  Map<TrainingItemType, List<TrainingItemId>> _groupIdsByType(
    List<TrainingItemId> ids,
  ) {
    final grouped = <TrainingItemType, List<TrainingItemId>>{
      for (final type in TrainingItemType.values) type: <TrainingItemId>[],
    };
    for (final id in ids) {
      grouped[id.type]!.add(id);
    }
    return grouped;
  }

  bool _shouldShowTypeStreak(TrainingItemType type, int count) {
    if (type == TrainingItemType.timeRandom) return false;
    return count > 1;
  }

  int _gridColumnsForType(TrainingItemType type, int count) {
    final safeCount = count <= 0 ? 1 : count;
    int preferred;
    switch (type) {
      case TrainingItemType.digits:
        preferred = 10;
        break;
      case TrainingItemType.base:
        preferred = 10;
        break;
      case TrainingItemType.hundreds:
        preferred = 9;
        break;
      case TrainingItemType.thousands:
        preferred = 5;
        break;
      case TrainingItemType.timeExact:
        preferred = 8;
        break;
      case TrainingItemType.timeQuarter:
        preferred = 8;
        break;
      case TrainingItemType.timeHalf:
        preferred = 8;
        break;
      case TrainingItemType.timeRandom:
        preferred = 1;
        break;
    }
    return preferred > safeCount ? safeCount : preferred;
  }

  List<_DailyStats> _buildDailyStats(
    Map<TrainingItemId, CardProgress> progressById,
    int days,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final stats = <int, _DailyStats>{};
    for (var i = 0; i < days; i += 1) {
      final day = start.add(Duration(days: i));
      stats[_dayKey(day)] = _DailyStats(day: day);
    }

    for (final progress in progressById.values) {
      for (final cluster in progress.clusters) {
        if (cluster.lastAnswerAt <= 0) continue;
        final day = DateTime.fromMillisecondsSinceEpoch(cluster.lastAnswerAt);
        final key = _dayKey(day);
        final stat = stats[key];
        if (stat == null) continue;
        stat.attempts += cluster.totalAttempts;
        stat.correct += cluster.correctCount;
      }
    }

    final ordered = stats.values.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return ordered;
  }

  _ForecastStats _buildForecastStats({
    required int remaining,
    required int learnedCount,
    required int totalAttempts,
    required List<_DailyStats> dailyStats,
  }) {
    final attemptsPerLearned =
        learnedCount == 0 ? null : totalAttempts / learnedCount;
    final attemptsRemaining = attemptsPerLearned == null
        ? null
        : (remaining * attemptsPerLearned).round();
    final attemptsHint = attemptsRemaining == null
        ? learnedCount == 0
            ? 'Learn 1+ cards to estimate'
            : 'Not enough data yet'
        : null;
    final totalAttemptsWindow = dailyStats.fold<int>(
      0,
      (sum, stat) => sum + stat.attempts,
    );
    final avgAttemptsPerDay = dailyStats.isEmpty
        ? 0.0
        : totalAttemptsWindow / dailyStats.length;
    final daysRemaining = attemptsRemaining != null && avgAttemptsPerDay > 0
        ? attemptsRemaining / avgAttemptsPerDay
        : null;
    return _ForecastStats(
      remaining: remaining,
      attemptsRemaining: attemptsRemaining,
      daysRemaining: daysRemaining,
      avgAttemptsPerDay: avgAttemptsPerDay,
      attemptsHint: attemptsHint,
    );
  }

  _NextDueInfo _resolveNextDue(
    Map<TrainingItemId, CardProgress> progressById,
  ) {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    var readyNowCount = 0;
    int? nextDueMillis;
    for (final progress in progressById.values) {
      if (progress.learned) continue;
      final due = progress.nextDue;
      if (due <= 0 || due <= nowMillis) {
        readyNowCount += 1;
      } else if (nextDueMillis == null || due < nextDueMillis) {
        nextDueMillis = due;
      }
    }
    return _NextDueInfo(
      readyNowCount: readyNowCount,
      nextDue: nextDueMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(nextDueMillis),
    );
  }

  int _dayKey(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  String _formatNextDue(int nextDue) {
    if (nextDue <= 0) return 'Ready now';
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    if (nextDue <= nowMillis) return 'Ready now';
    final diff = Duration(milliseconds: nextDue - nowMillis);
    return 'in ${_formatDuration(diff)}';
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }
    final totalHours = duration.inHours;
    if (totalHours < 24) {
      final minutes = totalMinutes % 60;
      return minutes == 0 ? '${totalHours}h' : '${totalHours}h ${minutes}m';
    }
    final days = duration.inDays;
    final hours = totalHours % 24;
    return hours == 0 ? '${days}d' : '${days}d ${hours}h';
  }

  String _formatDateTime(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  Set<TrainingItemId> _resolveHotIds(
    Map<TrainingItemId, CardProgress> progressById,
  ) {
    final entries = progressById.entries
        .where((entry) => !entry.value.learned && entry.value.totalAttempts > 0)
        .toList();
    entries.sort((a, b) {
      final diff = b.value.totalAttempts.compareTo(a.value.totalAttempts);
      if (diff != 0) return diff;
      return a.key.compareTo(b.key);
    });
    if (entries.length > 10) {
      entries.removeRange(10, entries.length);
    }
    return entries.map((entry) => entry.key).toSet();
  }

  int _clusterSuccessStreak(
    CardProgress progress,
    double successThreshold,
  ) {
    var count = 0;
    for (var i = progress.clusters.length - 1; i >= 0; i--) {
      final cluster = progress.clusters[i];
      if (!_isClusterSuccess(cluster, successThreshold)) {
        break;
      }
      count += 1;
    }
    return count;
  }

  bool _isClusterSuccess(CardCluster cluster, double threshold) {
    final total = cluster.totalAttempts;
    if (total == 0) return false;
    return (cluster.correctCount / total) >= threshold;
  }

  Color _progressColor(
    ColorScheme scheme,
    CardProgress progress,
    int streak,
  ) {
    if (progress.totalAttempts == 0) {
      return _notStartedColor(scheme);
    }
    if (progress.learned) {
      return _learnedColor(scheme);
    }
    final startedColor = _startedColor(scheme);
    if (streak <= 0) {
      return startedColor;
    }
    final t = (streak / _learnedStreakTarget).clamp(0.0, 1.0);
    return Color.lerp(startedColor, _learnedColor(scheme), t)!;
  }

  Color _notStartedColor(ColorScheme scheme) {
    return scheme.surfaceContainerHighest;
  }

  Color _startedColor(ColorScheme scheme) {
    return scheme.brightness == Brightness.dark
        ? Colors.amber.shade400
        : Colors.amber.shade200;
  }

  Color _learnedColor(ColorScheme scheme) {
    return scheme.brightness == Brightness.dark
        ? Colors.green.shade400
        : Colors.green.shade500;
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              scheme.surfaceContainerLow,
              accent.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final String label;

  const _LegendSwatch({
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    required this.label,
  }) : assert(color != null || gradient != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor ??
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: borderWidth,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  final double width;
  final _CoverageStats coverage;

  const _CoverageCard({
    required this.width,
    required this.coverage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCompact = width < 230;
    final total = coverage.total == 0 ? 1 : coverage.total;
    final notStartedValue =
        coverage.total == 0 ? 1.0 : coverage.notStarted.toDouble();
    final inProgressValue = coverage.inProgress.toDouble();
    final learnedValue = coverage.learned.toDouble();
    final notStartedColor = scheme.surfaceContainerHighest;
    final inProgressColor = scheme.brightness == Brightness.dark
        ? Colors.amber.shade400
        : Colors.amber.shade200;
    final learnedColor = scheme.brightness == Brightness.dark
        ? Colors.green.shade400
        : Colors.green.shade500;

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              scheme.surfaceContainerLow,
              scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!isCompact) ...[
              _coverageChart(
                notStartedValue,
                inProgressValue,
                learnedValue,
                notStartedColor,
                inProgressColor,
                learnedColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _coverageLegend(
                  theme,
                  scheme,
                  total,
                  notStartedColor,
                  inProgressColor,
                  learnedColor,
                ),
              ),
            ] else ...[
              Expanded(
                child: _coverageCompact(
                  theme,
                  scheme,
                  total,
                  notStartedValue,
                  inProgressValue,
                  learnedValue,
                  notStartedColor,
                  inProgressColor,
                  learnedColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _coverageCompact(
    ThemeData theme,
    ColorScheme scheme,
    int total,
    double notStartedValue,
    double inProgressValue,
    double learnedValue,
    Color notStartedColor,
    Color inProgressColor,
    Color learnedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coverage',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: _coverageChart(
            notStartedValue,
            inProgressValue,
            learnedValue,
            notStartedColor,
            inProgressColor,
            learnedColor,
          ),
        ),
        const SizedBox(height: 8),
        _coverageLegendItems(
          theme,
          total,
          notStartedColor,
          inProgressColor,
          learnedColor,
        ),
      ],
    );
  }

  Widget _coverageLegend(
    ThemeData theme,
    ColorScheme scheme,
    int total,
    Color notStartedColor,
    Color inProgressColor,
    Color learnedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coverage',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _coverageLegendItems(
          theme,
          total,
          notStartedColor,
          inProgressColor,
          learnedColor,
        ),
      ],
    );
  }

  Widget _coverageLegendItems(
    ThemeData theme,
    int total,
    Color notStartedColor,
    Color inProgressColor,
    Color learnedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendItem(
          color: learnedColor,
          label: 'Learned',
          value: '${coverage.learned}/$total',
        ),
        const SizedBox(height: 4),
        _LegendItem(
          color: inProgressColor,
          label: 'In progress',
          value: '${coverage.inProgress}/$total',
        ),
        const SizedBox(height: 4),
        _LegendItem(
          color: notStartedColor,
          label: 'Not started',
          value: '${coverage.notStarted}/$total',
        ),
      ],
    );
  }

  Widget _coverageChart(
    double notStartedValue,
    double inProgressValue,
    double learnedValue,
    Color notStartedColor,
    Color inProgressColor,
    Color learnedColor,
  ) {
    return SizedBox(
      width: 64,
      height: 64,
      child: PieChart(
        PieChartData(
          startDegreeOffset: -90,
          sectionsSpace: 2,
          centerSpaceRadius: 22,
          sections: [
            PieChartSectionData(
              value: notStartedValue,
              color: notStartedColor,
              title: '',
              radius: 12,
            ),
            PieChartSectionData(
              value: inProgressValue,
              color: inProgressColor,
              title: '',
              radius: 12,
            ),
            PieChartSectionData(
              value: learnedValue,
              color: learnedColor,
              title: '',
              radius: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final double width;
  final _ForecastStats forecast;
  final _NextDueInfo nextDueInfo;

  const _InsightCard({
    required this.width,
    required this.forecast,
    required this.nextDueInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final attemptsRemaining = forecast.attemptsRemaining;
    final daysRemaining = forecast.daysRemaining;
    final forecastLine = attemptsRemaining == null
        ? (forecast.attemptsHint ?? 'Not enough data')
        : '~$attemptsRemaining attempts';
    final daysLine = daysRemaining == null
        ? null
        : '~${daysRemaining.toStringAsFixed(1)} days';
    final nextDueLine = nextDueInfo.readyNowCount > 0
        ? 'Ready now (${nextDueInfo.readyNowCount})'
        : nextDueInfo.nextDue == null
            ? 'No upcoming due'
            : _formatDueLabel(nextDueInfo.nextDue!);

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              scheme.surfaceContainerLow,
              scheme.secondaryContainer.withValues(alpha: 0.18),
            ],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  size: 18,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Forecast',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              forecast.remaining == 0
                  ? 'All learned'
                  : '${forecast.remaining} remaining',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              forecastLine,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (daysLine != null) ...[
              const SizedBox(height: 2),
              Text(
                daysLine,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Next due',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              nextDueLine,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDueLabel(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.isNegative) return 'Ready now';
    final minutes = diff.inMinutes;
    if (minutes < 60) return 'in ${minutes}m';
    final hours = diff.inHours;
    if (hours < 24) {
      final rem = minutes % 60;
      return rem == 0 ? 'in ${hours}h' : 'in ${hours}h ${rem}m';
    }
    final days = diff.inDays;
    final remHours = hours % 24;
    return remHours == 0 ? 'in ${days}d' : 'in ${days}d ${remHours}h';
  }
}

class _MiniChartCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final List<double> values;
  final double? minY;
  final double? maxY;

  const _MiniChartCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.values,
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resolvedMax = _resolveMaxY(values);
    final resolvedMin = minY ?? 0;
    final resolvedMaxY = maxY ?? resolvedMax;

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              scheme.surfaceContainerLow,
              accent.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: LineChart(
                LineChartData(
                  minX: 0.0,
                  maxX: values.length > 1
                      ? (values.length - 1).toDouble()
                      : 1.0,
                  minY: resolvedMin,
                  maxY: resolvedMaxY,
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _buildSpots(values),
                      isCurved: true,
                      color: accent,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots(List<double> values) {
    if (values.isEmpty) return const <FlSpot>[];
    return [
      for (var i = 0; i < values.length; i += 1)
        FlSpot(i.toDouble(), values[i]),
    ];
  }

  double _resolveMaxY(List<double> values) {
    if (values.isEmpty) return 1;
    var maxValue = values.first;
    for (final value in values) {
      maxValue = math.max(maxValue, value);
    }
    if (maxValue == 0) return 1;
    return maxValue * 1.15;
  }
}

class _TypeCard extends StatelessWidget {
  final _TypeStats stats;
  final Widget? streakGrid;

  const _TypeCard({
    required this.stats,
    this.streakGrid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final learnedRatio = stats.total == 0 ? 0.0 : stats.learned / stats.total;
    final startedRatio = stats.total == 0 ? 0.0 : stats.started / stats.total;
    final accuracy =
        stats.attempts == 0 ? 0.0 : stats.correct / stats.attempts;

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              scheme.surfaceContainerLow,
              scheme.primaryContainer.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_typeLabel(stats.type)} ${_typeRange(stats.type)}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Learned',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${stats.learned}/${stats.total} | ${(learnedRatio * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: learnedRatio,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Started',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${stats.started}/${stats.total} | Acc. ${(accuracy * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: startedRatio,
              minHeight: 6,
              color: scheme.secondary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Sessions: ${stats.sessions}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Attempts: ${stats.attempts}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (streakGrid != null) ...[
              const SizedBox(height: 14),
              streakGrid!,
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final String label;
  final String value;

  const _DetailPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClusterRow extends StatelessWidget {
  final String dateLabel;
  final CardCluster cluster;
  final bool isSuccess;

  const _ClusterRow({
    required this.dateLabel,
    required this.cluster,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = cluster.totalAttempts;
    final accuracy = total == 0 ? 0.0 : cluster.correctCount / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green : scheme.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${(accuracy * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${cluster.correctCount}/${cluster.totalAttempts}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          if (cluster.skippedCount > 0)
            Text(
              'skip ${cluster.skippedCount}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CoverageStats {
  final int total;
  final int learned;
  final int inProgress;
  final int notStarted;

  const _CoverageStats({
    required this.total,
    required this.learned,
    required this.inProgress,
    required this.notStarted,
  });
}

class _ForecastStats {
  final int remaining;
  final int? attemptsRemaining;
  final double? daysRemaining;
  final double avgAttemptsPerDay;
  final String? attemptsHint;

  const _ForecastStats({
    required this.remaining,
    required this.attemptsRemaining,
    required this.daysRemaining,
    required this.avgAttemptsPerDay,
    required this.attemptsHint,
  });
}

class _NextDueInfo {
  final int readyNowCount;
  final DateTime? nextDue;

  const _NextDueInfo({
    required this.readyNowCount,
    required this.nextDue,
  });
}

class _DailyStats {
  final DateTime day;
  int attempts = 0;
  int correct = 0;

  _DailyStats({
    required this.day,
  });

  double get accuracy => attempts == 0 ? 0.0 : correct / attempts;
}

class _TypeStats {
  final TrainingItemType type;
  int total = 0;
  int learned = 0;
  int started = 0;
  int attempts = 0;
  int correct = 0;
  int sessions = 0;

  _TypeStats({
    required this.type,
  });
}

String _typeLabel(TrainingItemType type) {
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

String _typeRange(TrainingItemType type) {
  switch (type) {
    case TrainingItemType.digits:
      return '(0-9)';
    case TrainingItemType.base:
      return '(10-99)';
    case TrainingItemType.hundreds:
      return '(100-900)';
    case TrainingItemType.thousands:
      return '(1000-9000)';
    case TrainingItemType.timeExact:
      return '(HH:00)';
    case TrainingItemType.timeQuarter:
      return '(HH:15, HH:45)';
    case TrainingItemType.timeHalf:
      return '(HH:30)';
    case TrainingItemType.timeRandom:
      return '(HH:MM)';
  }
}

String _cardDisplayText(TrainingItemId id) {
  if (id.type == TrainingItemType.timeRandom) {
    return _typeLabel(id.type);
  }
  final number = id.number;
  if (number != null) return number.toString();
  final time = id.time;
  if (time != null) return time.displayText;
  return id.storageKey;
}
