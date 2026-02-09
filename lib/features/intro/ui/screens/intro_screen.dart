import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../training/data/card_progress.dart';
import '../../../training/data/number_cards.dart';
import '../../../training/data/progress_repository.dart';
import '../../../training/data/settings_repository.dart';
import '../../../training/domain/daily_session_stats.dart';
import '../../../training/domain/daily_study_summary.dart';
import '../../../training/domain/learning_language.dart';
import '../../../training/domain/session_progress_plan.dart';
import '../../../training/ui/screens/debug_settings_screen.dart';
import '../../../training/ui/screens/settings_screen.dart';
import '../../../training/ui/screens/statistics_screen.dart';
import '../../../training/ui/screens/training_screen.dart';
import '../../../training/ui/widgets/training_background.dart';
import 'about_screen.dart';

enum _IntroMenuAction { statistics, settings, debug, about }

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
  int _progressLoadRequestId = 0;
  bool _allLearned = false;
  bool _loadingProgress = true;
  int _cardsCompletedToday = 0;
  int _cardsTargetToday = DailyStudyPlan.cardLimit;
  int _sessionCardGoal = DailyStudyPlan.cardLimit;
  DailySessionStats _dailySessionStats = DailySessionStats.emptyFor(
    DateTime.now(),
  );

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
    final requestId = ++_progressLoadRequestId;
    final settingsRepository = SettingsRepository(widget.settingsBox);
    final language = settingsRepository.readLearningLanguage();
    final ids = buildAllCardIds();
    final progress = await _progressRepository.loadAll(ids, language: language);
    final learnedCount = progress.values
        .where((progress) => progress.learned)
        .length;
    final allLearned = ids.isNotEmpty && learnedCount == ids.length;
    final dailySummary = DailyStudySummary.fromProgress(progress.values);
    final dailySessionStats = settingsRepository.readDailySessionStats(
      now: DateTime.now(),
    );
    final sessionCardGoal = SessionProgressPlan.normalizeSessionSize(
      dailySummary.targetToday,
    );
    final cardsCompletedToday = dailySummary.completedToday < 0
        ? 0
        : dailySummary.completedToday;
    final cardsTargetToday = SessionProgressPlan.targetCards(
      cardsCompletedToday: cardsCompletedToday,
      sessionsCompleted: dailySessionStats.sessionsCompleted,
      sessionSize: sessionCardGoal,
    );

    if (!mounted || requestId != _progressLoadRequestId) return;
    setState(() {
      _language = language;
      _allLearned = allLearned;
      _loadingProgress = false;
      _cardsCompletedToday = cardsCompletedToday;
      _cardsTargetToday = cardsTargetToday;
      _sessionCardGoal = sessionCardGoal;
      _dailySessionStats = dailySessionStats;
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
              const infoCardHeight = 96.0;
              const layoutSafety = 4.0;

              final contentWidth =
                  constraints.maxWidth - (horizontalPadding * 2);
              final contentHeight =
                  constraints.maxHeight -
                  verticalPaddingTop -
                  verticalPaddingBottom;
              final effectiveWidth = math.min(contentWidth, maxContentWidth);
              final availableImageHeight = math.max(
                0.0,
                contentHeight -
                    (menuHeight +
                        gapAfterLogo +
                        gapAfterMascot +
                        infoCardHeight +
                        layoutSafety),
              );
              final maxWidthByHeight =
                  availableImageHeight / (1 + logoAspectRatio);
              final heroImageWidth = math.max(
                0.0,
                math.min(effectiveWidth * 0.9, maxWidthByHeight),
              );

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPaddingTop,
                  horizontalPadding,
                  verticalPaddingBottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: maxContentWidth,
                    ),
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
                                  case _IntroMenuAction.debug:
                                    _openDebugMenu(context);
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
                                if (kDebugMode)
                                  PopupMenuItem(
                                    value: _IntroMenuAction.debug,
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.bug_report_outlined,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Debug'),
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
                                  color: AppPalette.deepBlue,
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
        _buildDailyPlanActionCard(theme, context),
      ],
    );
  }

  Widget _buildDailyPlanActionCard(ThemeData theme, BuildContext context) {
    if (_loadingProgress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.black87,
      fontWeight: FontWeight.w600,
    );
    final subStyle = theme.textTheme.bodySmall?.copyWith(color: Colors.black54);
    final completed = _cardsCompletedToday;
    final goal = _cardsTargetToday;
    final sessionsCompleted = _dailySessionStats.sessionsCompleted;
    final sessionWord = sessionsCompleted == 1 ? 'session' : 'sessions';
    final sessionProgress = SessionProgressPlan.currentSessionProgress(
      cardsCompletedToday: completed,
      sessionSize: _sessionCardGoal,
    );
    final sessionBoundary = SessionProgressPlan.isSessionBoundary(
      cardsCompletedToday: completed,
      sessionSize: _sessionCardGoal,
    );
    final durationText = _formatDuration(_dailySessionStats.duration);
    final statusText = sessionBoundary
        ? '$sessionsCompleted $sessionWord completed today'
        : 'Current session: $sessionProgress/$_sessionCardGoal';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final infoColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today\'s plan', style: textStyle),
              const SizedBox(height: 4),
              Text('$completed of $goal cards', style: subStyle),
              Text(statusText, style: subStyle),
              Text('Duration today: $durationText', style: subStyle),
            ],
          );
          final actionButton = _buildStartButton(
            theme,
            context,
            expand: compact,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [infoColumn, const SizedBox(height: 12), actionButton],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: infoColumn),
              const SizedBox(width: 12),
              actionButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStartButton(
    ThemeData theme,
    BuildContext context, {
    required bool expand,
  }) {
    return SizedBox(
      width: expand ? double.infinity : 120,
      height: 44,
      child: FilledButton(
        onPressed: _allLearned
            ? null
            : () {
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
          backgroundColor: AppPalette.deepBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black12,
          disabledForegroundColor: Colors.black45,
          textStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(_allLearned ? 'All learned' : 'Start'),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => SettingsScreen(
              settingsBox: widget.settingsBox,
              progressBox: widget.progressBox,
              onProgressChanged: _loadProgress,
            ),
          ),
        )
        .then((_) => _loadProgress());
  }

  void _openDebugMenu(BuildContext context) {
    if (!kDebugMode) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => DebugSettingsScreen(
              settingsBox: widget.settingsBox,
              progressBox: widget.progressBox,
              onProgressChanged: _loadProgress,
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
          settingsBox: widget.settingsBox,
          language: _language,
        ),
      ),
    );
  }
}
