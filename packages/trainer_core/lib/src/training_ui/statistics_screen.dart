import 'package:flutter/material.dart';

import '../app_definition.dart';
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
                    for (final family in _familyRows(stats)) ...[
                      Card(
                        child: ListTile(
                          title: Text(family.label),
                          subtitle: Text('${family.learned}/${family.total}'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  List<_FamilyRow> _familyRows(TrainingStatsSnapshot stats) {
    final rows = <String, _FamilyRow>{};
    for (final card in stats.cards) {
      rows.putIfAbsent(
        card.family.storageKey,
        () => _FamilyRow(label: card.family.label),
      );
      final row = rows[card.family.storageKey]!;
      row.total += 1;
      final progress = stats.progressById[card.progressId];
      if (progress?.learned ?? false) {
        row.learned += 1;
      }
    }
    return rows.values.toList()
      ..sort((left, right) => left.label.compareTo(right.label));
  }
}

class _FamilyRow {
  _FamilyRow({required this.label});

  final String label;
  int total = 0;
  int learned = 0;
}
