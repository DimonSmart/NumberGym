import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:url_launcher/url_launcher.dart';

class VerbGymHomeScreen extends StatefulWidget {
  const VerbGymHomeScreen({
    super.key,
    required this.config,
    required this.appDefinition,
    required this.settingsBox,
    required this.progressBox,
  });

  final AppConfig config;
  final TrainingAppDefinition appDefinition;
  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;

  @override
  State<VerbGymHomeScreen> createState() => _VerbGymHomeScreenState();
}

class _VerbGymHomeScreenState extends State<VerbGymHomeScreen> {
  late final SettingsRepository _settingsRepository;
  late final ProgressRepository _progressRepository;
  late final TrainingStatsLoader _statsLoader;
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _settingsRepository = SettingsRepository(widget.settingsBox);
    _progressRepository = ProgressRepository(widget.progressBox);
    _statsLoader = TrainingStatsLoader(
      progressRepository: _progressRepository,
      settingsRepository: _settingsRepository,
      catalog: widget.appDefinition.catalog,
    );
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
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
    final resolvedLanguage = widget.appDefinition.supportedLanguages.contains(
      currentLanguage,
    )
        ? currentLanguage
        : widget.appDefinition.supportedLanguages.first;
    final profile = widget.appDefinition.profileOf(resolvedLanguage);

    return Scaffold(
      body: TrainingBackground(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xE6FFF7EA),
                Color(0xCCF7E8D2),
                Color(0xAAF4E1C8),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.config.homeTitle,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Fast tense drills for present, past, and future.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF30413C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Language'),
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
                        Text(
                          'Ship v1 with speech first',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Each verb card stores explicit accepted forms, so irregulars, multi-word English futures, and Spanish answers with or without pronouns behave predictably.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _openTraining,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start training'),
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
                      subtitle: 'Progress by tense family',
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
                                (language) =>
                                    widget.appDefinition.profileOf(language).label,
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
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          appDefinition: widget.appDefinition,
          settingsBox: widget.settingsBox,
          progressBox: widget.progressBox,
          onProgressChanged: () => setState(() {}),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
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
  }

  Future<void> _openDebug() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DebugSettingsScreen(
          appDefinition: widget.appDefinition,
          settingsBox: widget.settingsBox,
          progressBox: widget.progressBox,
          onProgressChanged: () => setState(() {}),
        ),
      ),
    );
  }

  Future<void> _openAbout() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFAF2),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.config.aboutTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(widget.config.aboutBody),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => _launchExternal(widget.config.repositoryUrl),
                  icon: const Icon(Icons.code),
                  label: const Text('Open repository'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      _launchExternal(widget.config.privacyPolicyUrl),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Open privacy notes'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                Icon(icon, color: theme.colorScheme.primary),
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
