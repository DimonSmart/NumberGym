import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../training/data/card_progress.dart';
import '../../../training/data/number_cards.dart';
import '../../../training/data/progress_repository.dart';
import '../../../training/data/settings_repository.dart';
import '../../../training/domain/learning_language.dart';
import '../../../training/ui/screens/settings_screen.dart';
import '../../../training/ui/screens/statistics_screen.dart';
import '../../../training/ui/screens/training_screen.dart';
import '../../../training/ui/widgets/training_background.dart';
import 'about_screen.dart';

enum _IntroMenuAction { statistics, settings, about }

class IntroScreen extends StatefulWidget {
  const IntroScreen({
    super.key,
    required this.settingsBox,
    required this.progressBox,
  });

  final Box<String> settingsBox;
  final Box<CardProgress> progressBox;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final ProgressRepository _progressRepository;
  late LearningLanguage _language;
  StreamSubscription? _progressSubscription;
  StreamSubscription? _settingsSubscription;
  bool _allLearned = false;
  bool _loadingProgress = true;

  @override
  void initState() {
    super.initState();
    _progressRepository = ProgressRepository(widget.progressBox);
    _language = SettingsRepository(widget.settingsBox).readLearningLanguage();
    _loadProgress();
    _progressSubscription = widget.progressBox.watch().listen(
      (_) => _loadProgress(),
    );
    _settingsSubscription = widget.settingsBox.watch().listen(
      (_) => _loadProgress(),
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final language = SettingsRepository(
      widget.settingsBox,
    ).readLearningLanguage();
    final ids = buildAllCardIds();
    final progress = await _progressRepository.loadAll(ids, language: language);
    final learnedCount = progress.values
        .where((progress) => progress.learned)
        .length;
    final allLearned = ids.isNotEmpty && learnedCount == ids.length;

    if (!mounted) return;
    setState(() {
      _language = language;
      _allLearned = allLearned;
      _loadingProgress = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: TrainingBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const horizontalPadding = 24.0;
              const verticalPaddingTop = 28.0;
              const verticalPaddingBottom = 24.0;
              const maxContentWidth = 520.0;
              const logoAspectRatio = 227 / 980;
              const menuHeight = 48.0;
              const gapAfterLogo = 12.0;
              const gapAfterMascot = 16.0;
              const ctaHeight = 52.0;
              const layoutSafety = 4.0;

              final contentWidth =
                  constraints.maxWidth - (horizontalPadding * 2);
              final contentHeight =
                  constraints.maxHeight - verticalPaddingTop - verticalPaddingBottom;
              final effectiveWidth = math.min(contentWidth, maxContentWidth);
              final availableImageHeight = math.max(
                0.0,
                contentHeight -
                    (menuHeight +
                        gapAfterLogo +
                        gapAfterMascot +
                        ctaHeight +
                        layoutSafety),
              );
              final maxWidthByHeight =
                  availableImageHeight / (1 + logoAspectRatio);
              final heroImageWidth =
                  math.max(0.0, math.min(effectiveWidth * 0.9, maxWidthByHeight));

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPaddingTop,
                  horizontalPadding,
                  verticalPaddingBottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxContentWidth),
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
                                  case _IntroMenuAction.about:
                                    _openAbout(context);
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
                                PopupMenuItem(
                                  value: _IntroMenuAction.about,
                                  child: Row(
                                    children: const [
                                      Icon(Icons.info_outline, size: 18),
                                      SizedBox(width: 8),
                                      Text('About'),
                                    ],
                                  ),
                                ),
                              ],
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.62),
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              tooltip: 'Menu',
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/numbers_gym_name.png',
                            width: heroImageWidth,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Spacer(),
                        _buildBottomContent(theme, context, heroImageWidth),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomContent(
    ThemeData theme,
    BuildContext context,
    double heroImageWidth,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/app_icon_transparent.png',
          width: heroImageWidth,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(height: 16),
        _buildCallToAction(theme, context),
      ],
    );
  }

  Widget _buildCallToAction(ThemeData theme, BuildContext context) {
    if (_loadingProgress) {
      return const SizedBox(
        width: double.infinity,
        height: 52,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_allLearned) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'Все выучено',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: Colors.black87,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TrainingScreen(
                settingsBox: widget.settingsBox,
                progressBox: widget.progressBox,
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
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => SettingsScreen(
              settingsBox: widget.settingsBox,
              progressBox: widget.progressBox,
            ),
          ),
        )
        .then((_) => _loadProgress());
  }

  void _openAbout(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AboutScreen()));
  }

  void _openStatistics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatisticsScreen(
          progressBox: widget.progressBox,
          language: _language,
        ),
      ),
    );
  }
}
