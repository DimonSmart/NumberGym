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
            ? ListTile(
                title: Text(title),
                subtitle: Text('${family.learnedCards}/${family.totalCards}'),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Concepts: ${family.learnedConcepts}/${family.totalConcepts}'
                      ' · Cards: ${family.learnedCards}/${family.totalCards}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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

class _ConceptProgressGrid extends StatelessWidget {
  const _ConceptProgressGrid({
    required this.concepts,
    required this.maxColumns,
  });

  final List<TrainingStatsConceptProgress> concepts;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(
          width: constraints.maxWidth,
          maxColumns: maxColumns,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: concepts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.28,
          ),
          itemBuilder: (context, index) {
            return _CompactConceptTile(concept: concepts[index]);
          },
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
  const _CompactConceptTile({required this.concept});

  final TrainingStatsConceptProgress concept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _conceptTitle(concept.concept);
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Tooltip(
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
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: concept.progressValue,
              minHeight: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${concept.learnedCards}/${concept.totalCards}',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
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
                  Text(
                    '${concept.learnedCards}/${concept.totalCards}',
                    style: theme.textTheme.bodySmall,
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

String _conceptTitle(ExerciseConcept concept) {
  final baseLabel = concept.baseLabel.trim();
  if (baseLabel.isNotEmpty) {
    return baseLabel;
  }
  return concept.learningLabel.trim();
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
