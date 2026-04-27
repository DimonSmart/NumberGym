import 'package:flutter/material.dart';

import '../app_definition.dart';
import '../exercise_models.dart';
import '../training_stats_loader.dart';
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
                      _FamilyProgressCard(family: family),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FamilyProgressCard extends StatelessWidget {
  const _FamilyProgressCard({required this.family});

  final TrainingStatsFamilyProgress family;

  @override
  Widget build(BuildContext context) {
    final concepts = family.concepts;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: concepts.isEmpty
            ? ListTile(
                title: Text(family.family.label),
                subtitle: Text('${family.learnedCards}/${family.totalCards}'),
              )
            : ExpansionTile(
                title: Text(family.family.label),
                subtitle: Text(
                  'Concepts: ${family.learnedConcepts}/${family.totalConcepts}'
                  ' · Cards: ${family.learnedCards}/${family.totalCards}',
                ),
                children: [
                  for (final concept in concepts)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        concept.learned
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: concept.learned
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      title: Text(_conceptTitle(concept.concept)),
                      trailing: Text(
                        '${concept.learnedCards}/${concept.totalCards}',
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _conceptTitle(ExerciseConcept concept) {
    final label = concept.label.trim();
    final secondaryLabel = concept.secondaryLabel.trim();
    if (secondaryLabel.isEmpty || secondaryLabel == label) {
      return label;
    }
    return '$label / $secondaryLabel';
  }
}
