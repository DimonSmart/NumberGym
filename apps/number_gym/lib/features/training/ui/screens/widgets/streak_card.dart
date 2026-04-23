import 'package:flutter/material.dart';

import '../../../domain/study_streak_service.dart';
import 'stats_card_surface.dart';

class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.snapshot});

  final StudyStreakSnapshot snapshot;

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdayShort = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final streakDays = snapshot.currentStreakDays;
    final streakWord = streakDays == 1 ? 'day in a row' : 'days in a row';
    final monthLabel =
        '${_monthNames[snapshot.monthStart.month - 1]} ${snapshot.monthStart.year}';

    return StatsCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Streak',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                monthLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: streakDays > 0
                    ? Colors.deepOrangeAccent
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                '$streakDays',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  streakWord,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${snapshot.activeDaysInMonth} active days this month',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildCalendarGrid(theme),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(color: theme.colorScheme.primaryContainer),
              const SizedBox(width: 6),
              Text('active day', style: theme.textTheme.bodySmall),
              const SizedBox(width: 14),
              const Icon(Icons.flag, size: 12),
              const SizedBox(width: 4),
              Text('2+ sessions', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    final cells = <StudyStreakDaySnapshot?>[
      for (var i = 0; i < snapshot.firstWeekdayOffset; i += 1) null,
      ...snapshot.monthDays,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final weekRows = <Widget>[];
    for (var rowStart = 0; rowStart < cells.length; rowStart += 7) {
      final week = cells.sublist(rowStart, rowStart + 7);
      weekRows.add(
        Row(
          children: [
            for (final day in week)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _buildDayCell(theme, day),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayShort)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...weekRows,
      ],
    );
  }

  Widget _buildDayCell(ThemeData theme, StudyStreakDaySnapshot? day) {
    if (day == null) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }

    final hasActivity = day.hasActivity;
    final hasMultipleSessions = day.hasMultipleSessions;
    final isToday = _isSameDay(day.day, snapshot.today);
    final isFuture = day.day.isAfter(snapshot.today);

    final baseColor = hasActivity
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final borderColor = isToday
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.65);
    final textColor = isFuture
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
        : hasActivity
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${day.day.day}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (hasMultipleSessions)
              Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  Icons.flag,
                  size: 9,
                  color: hasActivity
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
