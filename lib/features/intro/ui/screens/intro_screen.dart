import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../training/data/card_progress.dart';
import '../../../training/data/settings_repository.dart';
import '../../../training/ui/screens/settings_screen.dart';
import '../../../training/ui/screens/statistics_screen.dart';
import '../../../training/ui/screens/training_screen.dart';

enum _IntroMenuAction { statistics, settings }

class IntroScreen extends StatelessWidget {
  const IntroScreen({
    super.key,
    required this.settingsBox,
    required this.progressBox,
  });

  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/intro.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      PopupMenuButton<_IntroMenuAction>(
                        onSelected: (value) {
                          switch (value) {
                            case _IntroMenuAction.statistics:
                              _openStatistics(context);
                              break;
                            case _IntroMenuAction.settings:
                              _openSettings(context);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: _IntroMenuAction.statistics,
                            child: Row(
                              children: const [
                                Icon(Icons.bar_chart, size: 18),
                                SizedBox(width: 8),
                                Text('Statistics'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _IntroMenuAction.settings,
                            child: Row(
                              children: const [
                                Icon(Icons.settings, size: 18),
                                SizedBox(width: 8),
                                Text('Settings'),
                              ],
                            ),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        tooltip: 'Menu',
                      ),
                    ],
                  ),
                  Text(
                    'Numbers Gym',
                    style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ) ??
                        const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Practice English numbers by listening, speaking, and quick '
                    'quizzes. Build confidence in a few minutes a day.',
                    style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ) ??
                        const TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          color: Colors.white70,
                        ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => TrainingScreen(
                              settingsBox: settingsBox,
                              progressBox: progressBox,
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          settingsBox: settingsBox,
          progressBox: progressBox,
        ),
      ),
    );
  }

  void _openStatistics(BuildContext context) {
    final language = SettingsRepository(settingsBox).readLearningLanguage();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            StatisticsScreen(progressBox: progressBox, language: language),
      ),
    );
  }
}
