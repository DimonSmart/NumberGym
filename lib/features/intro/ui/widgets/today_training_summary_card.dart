import 'package:flutter/material.dart';

import '../../../training/domain/daily_session_stats.dart';

class TodayTrainingSummaryCard extends StatelessWidget {
  const TodayTrainingSummaryCard({
    super.key,
    required this.stats,
    required this.cardsCompletedToday,
  });

  final DailySessionStats stats;
  final int cardsCompletedToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.black87,
      fontWeight: FontWeight.w700,
    );
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.black54,
    );
    final sessionWord = stats.sessionsCompleted == 1 ? 'session' : 'sessions';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today you already trained', style: titleStyle),
          const SizedBox(height: 4),
          Text('${stats.sessionsCompleted} $sessionWord', style: bodyStyle),
          Text('Cards completed: $cardsCompletedToday', style: bodyStyle),
          Text(
            'Duration: ${_formatDuration(stats.duration)}',
            style: bodyStyle,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final paddedSeconds = seconds.toString().padLeft(2, '0');
    return '$minutes:$paddedSeconds';
  }
}
