import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trainer_core/trainer_core.dart' hide AppPalette;

import 'core/theme/app_palette.dart';
import 'features/intro/ui/screens/about_screen.dart';

class NumberGymHomeScreen extends StatefulWidget {
  const NumberGymHomeScreen({
    super.key,
    required this.config,
    required this.appDefinition,
    required this.settingsBox,
    required this.progressBox,
    this.statsLoader,
    this.packageInfoLoader,
  });

  final AppConfig config;
  final TrainingAppDefinition appDefinition;
  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;
  final TrainingStatsLoader? statsLoader;
  final Future<PackageInfo> Function()? packageInfoLoader;

  @override
  State<NumberGymHomeScreen> createState() => _NumberGymHomeScreenState();
}

class _NumberGymHomeScreenState extends State<NumberGymHomeScreen> {
  late final SettingsRepository _settingsRepository;
  late final ProgressRepository _progressRepository;
  late final TrainingStatsLoader _statsLoader;

  TrainingStatsSnapshot? _stats;
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _progressRepository = ProgressRepository(widget.progressBox);
    _statsLoader =
        widget.statsLoader ??
        TrainingStatsLoader(
          progressRepository: _progressRepository,
          settingsRepository: _settingsRepository,
          catalog: widget.appDefinition.catalog,
        );
    _loadStats();
    _loadVersion();
  }

  Future<void> _loadStats() async {
    final stats = await _statsLoader.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _stats = stats;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo =
          await (widget.packageInfoLoader ?? PackageInfo.fromPlatform)();
      if (!mounted) {
        return;
      }
      setState(() {
        _versionLabel = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _versionLabel = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLanguage = _settingsRepository.readLearningLanguage();
    final resolvedLanguage =
        widget.appDefinition.supportedLanguages.contains(currentLanguage)
        ? currentLanguage
        : widget.appDefinition.supportedLanguages.first;
    final profile = widget.appDefinition.profileOf(resolvedLanguage);
    final stats = _stats;

    return Scaffold(
      body: TrainingBackground(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFFF8FBFF),
                Color(0xFFEAF3FF),
                Color(0xFFDCEBFF),
              ],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.config.homeTitle,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                          color: AppPalette.deepBlue,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Language',
                              style: theme.textTheme.labelMedium,
                            ),
                            Text(
                              profile.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Image.asset(
                            widget.config.heroAssetPath,
                            fit: BoxFit.contain,
                            height: 44,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Drill numbers, time, and phone formats',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'The active app shell now reads NumberGym content from packages and runs sessions through trainer_core. Speech, listening, random time, phone formats, and pronunciation review stay in one flow.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _openTraining,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.deepBlue,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start training'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (stats != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 12,
                        children: [
                          _StatChip(
                            label: 'Learned',
                            value: '${stats.learnedCount}/${stats.totalCards}',
                          ),
                          _StatChip(
                            label: 'Today',
                            value: stats.dailySummary.completedToday.toString(),
                          ),
                          _StatChip(
                            label: 'Streak',
                            value:
                                '${stats.streakSnapshot.currentStreakDays} days',
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _HomeActionCard(
                      title: 'Settings',
                      subtitle: 'Language, voice, progress reset',
                      icon: Icons.tune,
                      onTap: _openSettings,
                    ),
                    _HomeActionCard(
                      title: 'Statistics',
                      subtitle: 'Progress by family',
                      icon: Icons.bar_chart,
                      onTap: _openStatistics,
                    ),
                    _HomeActionCard(
                      title: 'About',
                      subtitle: 'Version, repo, privacy links',
                      icon: Icons.info_outline,
                      onTap: _openAbout,
                    ),
                    if (kDebugMode)
                      _HomeActionCard(
                        title: 'Debug',
                        subtitle: 'Forced family and mode filters',
                        icon: Icons.bug_report_outlined,
                        onTap: _openDebug,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supported languages',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.appDefinition.supportedLanguages
                              .map(
                                (language) => widget.appDefinition
                                    .profileOf(language)
                                    .label,
                              )
                              .join('  |  '),
                        ),
                        if (_versionLabel != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Version $_versionLabel',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTraining() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TrainingScreen(
          appDefinition: widget.appDefinition,
          settingsBox: widget.settingsBox,
          progressBox: widget.progressBox,
        ),
      ),
    );
    await _loadStats();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          appDefinition: widget.appDefinition,
          settingsBox: widget.settingsBox,
          progressBox: widget.progressBox,
          onProgressChanged: _loadStats,
        ),
      ),
    );
    await _loadStats();
  }

  Future<void> _openStatistics() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StatisticsScreen(
          appDefinition: widget.appDefinition,
          statsLoader: _statsLoader,
        ),
      ),
    );
    await _loadStats();
  }

  Future<void> _openDebug() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DebugSettingsScreen(
          appDefinition: widget.appDefinition,
          settingsBox: widget.settingsBox,
          progressBox: widget.progressBox,
          onProgressChanged: _loadStats,
        ),
      ),
    );
    await _loadStats();
  }

  Future<void> _openAbout() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const AboutScreen()));
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppPalette.deepBlue),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.iceBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
