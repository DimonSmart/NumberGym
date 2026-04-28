import 'package:flutter/material.dart';

import '../app_definition.dart';
import '../exercise_models.dart';
import '../training_stats_loader.dart';
import '../training/domain/learning_language.dart';
import 'widgets/training_background.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.appDefinition,
    required this.statsLoader,
  });

  final TrainingAppDefinition appDefinition;
  final TrainingStatsLoader statsLoader;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  TrainingStatsSnapshot? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snapshot = await widget.statsLoader.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _stats = snapshot;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      body: TrainingBackground(
        child: SafeArea(
          child: stats == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Statistics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total cards: ${stats.totalCards}'),
                            Text('Learned: ${stats.learnedCount}'),
                            if (stats.hasConceptProgress)
                              Text(
                                'Learned concepts by tense: '
                                '${stats.learnedConceptCount}/${stats.totalConcepts}',
                              ),
                            Text(
                              'Completed today: ${stats.dailySummary.completedToday}',
                            ),
                            Text(
                              'Current streak: ${stats.streakSnapshot.currentStreakDays}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final family in stats.familyProgress)
                      _FamilyProgressCard(
                        family: family,
                        baseLanguage: stats.baseLanguage,
                        learningLanguage: stats.language,
                        displayConfig: widget.appDefinition.statisticsDisplay,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FamilyProgressCard extends StatelessWidget {
  const _FamilyProgressCard({
    required this.family,
    required this.baseLanguage,
    required this.learningLanguage,
    required this.displayConfig,
  });

  final TrainingStatsFamilyProgress family;
  final LearningLanguage baseLanguage;
  final LearningLanguage learningLanguage;
  final StatisticsDisplayConfig displayConfig;

  @override
  Widget build(BuildContext context) {
    final concepts = family.concepts;
    final title = _familyTitle(
      family.family,
      baseLanguage: baseLanguage,
      learningLanguage: learningLanguage,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: concepts.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${family.learnedCards}/${family.totalCards}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: family.totalCards == 0
                            ? 0
                            : family.learnedCards / family.totalCards,
                        minHeight: 6,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FamilyCardProgressGrid(
                      cards: family.cards,
                      gridConfig: displayConfig.cardGridForFamily(
                        family.family,
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (displayConfig.conceptDisplayMode ==
                        StatisticsConceptDisplayMode.compactGrid)
                      _ConceptProgressGrid(
                        concepts: concepts,
                        maxColumns: displayConfig.compactGridMaxColumns,
                      )
                    else
                      for (final concept in concepts) ...[
                        _ConceptProgressRow(concept: concept),
                        if (concept != concepts.last) const Divider(height: 18),
                      ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _FamilyCardProgressGrid extends StatelessWidget {
  const _FamilyCardProgressGrid({
    required this.cards,
    required this.gridConfig,
  });

  final List<TrainingStatsCardProgress> cards;
  final StatisticsCardGridConfig gridConfig;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(
          width: constraints.maxWidth,
          gridConfig: gridConfig,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            return _CompactCardTile(cardProgress: cards[index]);
          },
        );
      },
    );
  }

  int _columnCount({
    required double width,
    required StatisticsCardGridConfig gridConfig,
  }) {
    final maxColumns = gridConfig.maxColumns < 1 ? 1 : gridConfig.maxColumns;
    final minTileWidth = gridConfig.minTileWidth <= 0
        ? const StatisticsCardGridConfig().minTileWidth
        : gridConfig.minTileWidth;
    final columnsByWidth = (width / minTileWidth).floor();
    final minColumns = maxColumns < 2 ? 1 : 2;
    final columns = columnsByWidth.clamp(minColumns, maxColumns);
    return columns.toInt();
  }
}

class _CompactCardTile extends StatelessWidget {
  const _CompactCardTile({required this.cardProgress});

  final TrainingStatsCardProgress cardProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = _formatCreditedCorrect(
      creditedCorrectAttempts:
          cardProgress.learningProgress.creditedCorrectAttempts,
      requiredCorrectAttempts:
          cardProgress.learningProgress.requiredCorrectAttempts,
    );
    final label = _cardDisplayTitle(cardProgress.card);
    final backgroundColor = _cardProgressColor(theme.colorScheme, cardProgress);
    final textColor =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Tooltip(
      message: '$label: $score',
      child: Semantics(
        label: '$label, $score',
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: cardProgress.learned
                  ? theme.colorScheme.primary.withValues(alpha: 0.55)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  score,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _cardProgressColor(
    ColorScheme colorScheme,
    TrainingStatsCardProgress cardProgress,
  ) {
    if (cardProgress.learned) {
      return colorScheme.primaryContainer;
    }
    if (cardProgress.progress.totalAttempts == 0) {
      return colorScheme.surfaceContainerHighest;
    }
    return Color.lerp(
      colorScheme.tertiaryContainer,
      colorScheme.primaryContainer,
      cardProgress.learningProgress.progressValue,
    )!;
  }
}

class _ConceptProgressGrid extends StatefulWidget {
  const _ConceptProgressGrid({
    required this.concepts,
    required this.maxColumns,
  });

  final List<TrainingStatsConceptProgress> concepts;
  final int maxColumns;

  @override
  State<_ConceptProgressGrid> createState() => _ConceptProgressGridState();
}

class _ConceptProgressGridState extends State<_ConceptProgressGrid> {
  String? _expandedConceptId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(
          width: constraints.maxWidth,
          maxColumns: widget.maxColumns,
        );
        const spacing = 8.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final concept in widget.concepts)
              _CompactConceptTile(
                concept: concept,
                expanded: _expandedConceptId == concept.concept.id,
                width: _expandedConceptId == concept.concept.id
                    ? constraints.maxWidth
                    : tileWidth,
                onTap: () {
                  setState(() {
                    _expandedConceptId =
                        _expandedConceptId == concept.concept.id
                        ? null
                        : concept.concept.id;
                  });
                },
              ),
          ],
        );
      },
    );
  }

  int _columnCount({required double width, required int maxColumns}) {
    final safeMaxColumns = maxColumns < 1 ? 1 : maxColumns;
    final columnsByWidth = (width / 96).floor();
    final minColumns = safeMaxColumns < 2 ? 1 : 2;
    final columns = columnsByWidth.clamp(minColumns, safeMaxColumns);
    return columns.toInt();
  }
}

class _CompactConceptTile extends StatelessWidget {
  const _CompactConceptTile({
    required this.concept,
    required this.expanded,
    required this.width,
    required this.onTap,
  });

  final TrainingStatsConceptProgress concept;
  final bool expanded;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        expanded: expanded,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: concept.learned
                    ? theme.colorScheme.primary.withValues(alpha: 0.55)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConceptTileSummary(concept: concept, expanded: expanded),
                if (expanded) ...[
                  const Divider(height: 14),
                  for (final cardProgress in concept.cards) ...[
                    _ConceptCardProgressRow(cardProgress: cardProgress),
                    if (cardProgress != concept.cards.last)
                      const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConceptTileSummary extends StatelessWidget {
  const _ConceptTileSummary({required this.concept, required this.expanded});

  final TrainingStatsConceptProgress concept;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: concept.progressValue,
        minHeight: 5,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
    final footer = Row(
      children: [
        Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const Spacer(),
        Text(
          _formatCreditedCorrect(
            creditedCorrectAttempts: concept.creditedCorrectAttempts,
            requiredCorrectAttempts: concept.requiredCorrectAttempts,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        expanded
            ? _ExpandedConceptTitle(concept: concept.concept)
            : Expanded(child: _CollapsedConceptTitle(concept: concept.concept)),
        const SizedBox(height: 6),
        progress,
        const SizedBox(height: 4),
        footer,
      ],
    );

    if (expanded) {
      return summary;
    }
    return SizedBox(height: 82, child: summary);
  }
}

class _CollapsedConceptTitle extends StatelessWidget {
  const _CollapsedConceptTitle({required this.concept});

  final ExerciseConcept concept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _conceptTitle(concept);
    return Tooltip(
      message: title,
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ExpandedConceptTitle extends StatelessWidget {
  const _ExpandedConceptTitle({required this.concept});

  final ExerciseConcept concept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseTitle = concept.baseLabel.trim();
    final learningTitle = concept.learningLabel.trim();
    final primaryTitle = baseTitle.isEmpty ? learningTitle : baseTitle;
    final showLearningTitle =
        learningTitle.isNotEmpty &&
        learningTitle.toLowerCase() != primaryTitle.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primaryTitle,
          softWrap: true,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        if (showLearningTitle) ...[
          const SizedBox(height: 2),
          Text(
            learningTitle,
            softWrap: true,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.15,
            ),
          ),
        ],
      ],
    );
  }
}

class _ConceptCardProgressRow extends StatelessWidget {
  const _ConceptCardProgressRow({required this.cardProgress});

  final TrainingStatsCardProgress cardProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _cardTitle(cardProgress.card);
    final labelStyle = theme.textTheme.labelSmall;
    return LayoutBuilder(
      builder: (context, constraints) {
        const progressWidth = 76.0;
        const scoreWidth = 42.0;
        const gap = 8.0;
        const trailingWidth = progressWidth + scoreWidth + gap * 2;
        final firstLineWidth = (constraints.maxWidth - trailingWidth).clamp(
          48.0,
          constraints.maxWidth,
        );
        final split = _splitTextForFirstLine(
          text: label,
          style: labelStyle,
          maxWidth: firstLineWidth,
          textDirection: Directionality.of(context),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: firstLineWidth,
                  child: Text(
                    split.firstLine,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: labelStyle,
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: progressWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: cardProgress.learningProgress.progressValue,
                      minHeight: 5,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: scoreWidth,
                  child: Text(
                    _formatCreditedCorrect(
                      creditedCorrectAttempts:
                          cardProgress.learningProgress.creditedCorrectAttempts,
                      requiredCorrectAttempts:
                          cardProgress.learningProgress.requiredCorrectAttempts,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ],
            ),
            if (split.remainingLines.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(split.remainingLines, softWrap: true, style: labelStyle),
            ],
          ],
        );
      },
    );
  }
}

class _ConceptProgressRow extends StatelessWidget {
  const _ConceptProgressRow({required this.concept});

  final TrainingStatsConceptProgress concept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = concept.progressValue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            concept.learned ? Icons.check_circle : Icons.radio_button_unchecked,
            color: concept.learned
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_conceptTitle(concept.concept)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    alignment: WrapAlignment.end,
                    children: [
                      Text(
                        _formatCreditedCorrect(
                          creditedCorrectAttempts:
                              concept.creditedCorrectAttempts,
                          requiredCorrectAttempts:
                              concept.requiredCorrectAttempts,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatCreditedCorrect({
  required int creditedCorrectAttempts,
  required int requiredCorrectAttempts,
}) {
  return '$creditedCorrectAttempts/$requiredCorrectAttempts';
}

class _SplitText {
  const _SplitText({required this.firstLine, required this.remainingLines});

  final String firstLine;
  final String remainingLines;
}

_SplitText _splitTextForFirstLine({
  required String text,
  required TextStyle? style,
  required double maxWidth,
  required TextDirection textDirection,
}) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return const _SplitText(firstLine: '', remainingLines: '');
  }
  if (_fitsSingleLine(
    text: normalized,
    style: style,
    maxWidth: maxWidth,
    textDirection: textDirection,
  )) {
    return _SplitText(firstLine: normalized, remainingLines: '');
  }

  var low = 1;
  var high = normalized.length;
  while (low < high) {
    final middle = ((low + high + 1) / 2).floor();
    if (_fitsSingleLine(
      text: normalized.substring(0, middle).trimRight(),
      style: style,
      maxWidth: maxWidth,
      textDirection: textDirection,
    )) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }

  final fittedLength = low.clamp(1, normalized.length);
  final wordBoundary = normalized.lastIndexOf(' ', fittedLength - 1);
  final splitAt = wordBoundary > 0 ? wordBoundary : fittedLength;
  final firstLine = normalized.substring(0, splitAt).trimRight();
  final remainingLines = normalized.substring(splitAt).trimLeft();
  return _SplitText(firstLine: firstLine, remainingLines: remainingLines);
}

bool _fitsSingleLine({
  required String text,
  required TextStyle? style,
  required double maxWidth,
  required TextDirection textDirection,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    maxLines: 1,
  )..layout(maxWidth: maxWidth);
  return !painter.didExceedMaxLines && painter.width <= maxWidth;
}

String _conceptTitle(ExerciseConcept concept) {
  final baseLabel = concept.baseLabel.trim();
  if (baseLabel.isNotEmpty) {
    return baseLabel;
  }
  return concept.learningLabel.trim();
}

String _cardTitle(ExerciseCard card) {
  final promptText = card.promptText.trim();
  if (promptText.isNotEmpty) {
    return promptText;
  }
  final displayText = card.displayText.trim();
  if (displayText.isNotEmpty) {
    return displayText;
  }
  return card.id.variantId;
}

String _cardDisplayTitle(ExerciseCard card) {
  final displayText = card.displayText.trim();
  if (displayText.isNotEmpty) {
    return displayText;
  }
  final promptText = card.promptText.trim();
  if (promptText.isNotEmpty) {
    return promptText;
  }
  return card.id.variantId;
}

String _familyTitle(
  ExerciseFamily family, {
  required LearningLanguage baseLanguage,
  required LearningLanguage learningLanguage,
}) {
  final learningLabel = family.labelFor(learningLanguage).trim();
  final baseLabel = family.labelFor(baseLanguage).trim();
  if (baseLabel.isEmpty ||
      learningLabel.toLowerCase() == baseLabel.toLowerCase()) {
    return learningLabel.isEmpty ? family.label : learningLabel;
  }
  if (learningLabel.isEmpty) {
    return baseLabel;
  }
  return '$learningLabel / $baseLabel';
}
