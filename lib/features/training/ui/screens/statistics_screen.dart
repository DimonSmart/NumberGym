import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../data/card_progress.dart';
import '../../data/number_cards.dart';
import '../../data/progress_repository.dart';
import '../widgets/training_background.dart';

class StatisticsScreen extends StatefulWidget {
  final Box<CardProgress> progressBox;

  const StatisticsScreen({
    super.key,
    required this.progressBox,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final ProgressRepository _progressRepository;
  Map<int, CardProgress> _progressById = {};
  List<int> _gridIds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _progressRepository = ProgressRepository(widget.progressBox);
    _load();
  }

  Future<void> _load() async {
    final cards = buildNumberCards();
    final ids = cards.map((c) => c.id).toList();
    final progress = await _progressRepository.loadAll(ids);
    
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

    final totalAttempts = _progressById.values.fold<int>(
      0,
      (sum, progress) => sum + progress.totalAttempts,
    );
    final totalCorrect = _progressById.values.fold<int>(
      0,
      (sum, progress) => sum + progress.totalCorrect,
    );
    final accuracy = totalAttempts == 0 ? 0.0 : totalCorrect / totalAttempts;

    final maxAttempts = gridProgress.values.fold<int>(
      0,
      (current, progress) =>
          progress.totalAttempts > current ? progress.totalAttempts : current,
    );

    final hotIds = _resolveHotIds(gridProgress);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(theme, totalAttempts, totalCorrect, accuracy),
          const SizedBox(height: 20),
          _buildAccuracyBanner(theme, totalAttempts, totalCorrect, accuracy),
          const SizedBox(height: 26),
          Text(
            'Streak grid',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Each cell shows the number and its current correct streak.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildLegend(theme, maxAttempts),
          const SizedBox(height: 14),
          _buildGrid(theme, _gridIds, gridProgress, maxAttempts, hotIds),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    ThemeData theme,
    int totalAttempts,
    int totalCorrect,
    double accuracy,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 3 : 2;
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
              title: 'Correct',
              value: totalCorrect.toString(),
              icon: Icons.check_circle_outline,
              accent: theme.colorScheme.secondary,
            ),
            _StatCard(
              width: cardWidth,
              title: 'Accuracy',
              value: '${(accuracy * 100).toStringAsFixed(1)}%',
              subtitle:
                  totalAttempts == 0 ? 'No attempts yet' : '$totalCorrect / $totalAttempts',
              icon: Icons.insights,
              accent: theme.colorScheme.tertiary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccuracyBanner(
    ThemeData theme,
    int totalAttempts,
    int totalCorrect,
    double accuracy,
  ) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.45),
            scheme.secondaryContainer.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall accuracy',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${(accuracy * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$totalCorrect / $totalAttempts',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: accuracy,
              minHeight: 10,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme, int maxAttempts) {
    final scheme = theme.colorScheme;
    final lowColor = _effortColor(scheme, 0, maxAttempts);
    final highColor = maxAttempts == 0
        ? scheme.primaryContainer
        : _effortColor(scheme, maxAttempts, maxAttempts);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendSwatch(
          color: lowColor,
          label: 'Low effort',
        ),
        _LegendSwatch(
          color: highColor,
          label: 'High effort',
        ),
        _LegendSwatch(
          color: Colors.red.shade300,
          label: 'Top 10 not learned',
        ),
      ],
    );
  }

  Widget _buildGrid(
    ThemeData theme,
    List<int> gridIds,
    Map<int, CardProgress> progressById,
    int maxAttempts,
    Set<int> hotIds,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 10;
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
            ),
            itemBuilder: (context, index) {
              final id = gridIds[index];
              final progress = progressById[id] ?? CardProgress.empty;
              final attempts = progress.totalAttempts;
              final streak = _consecutiveCorrect(progress.lastAttempts);
              final baseColor =
                  _effortColor(theme.colorScheme, attempts, maxAttempts);
              final isHot = hotIds.contains(id);
              final backgroundColor = isHot
                  ? Color.lerp(baseColor, Colors.red.shade200, 0.4)!
                  : baseColor;
              final borderColor = isHot
                  ? Colors.red.shade400
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
              final textColor =
                  ThemeData.estimateBrightnessForColor(backgroundColor) ==
                          Brightness.dark
                      ? Colors.white
                      : theme.colorScheme.onSurface;

              return Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          id.toString(),
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
              );
            },
          ),
        );
      },
    );
  }

  Set<int> _resolveHotIds(Map<int, CardProgress> progressById) {
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

  int _consecutiveCorrect(List<bool> attempts) {
    var count = 0;
    for (var i = attempts.length - 1; i >= 0; i--) {
      if (!attempts[i]) break;
      count += 1;
    }
    return count;
  }

  Color _effortColor(ColorScheme scheme, int attempts, int maxAttempts) {
    if (maxAttempts <= 0) {
      return scheme.surfaceContainerHighest;
    }
    final t = (attempts / maxAttempts).clamp(0.0, 1.0);
    return Color.lerp(
      scheme.surfaceContainerLowest,
      scheme.primaryContainer,
      t,
    )!;
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
  final Color color;
  final String label;

  const _LegendSwatch({
    required this.color,
    required this.label,
  });

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
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
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
