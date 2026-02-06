String formatDurationShort(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 60) return '${totalMinutes}m';

  final totalHours = duration.inHours;
  if (totalHours < 24) {
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '${totalHours}h' : '${totalHours}h ${minutes}m';
  }

  final days = duration.inDays;
  final hours = totalHours % 24;
  return hours == 0 ? '${days}d' : '${days}d ${hours}h';
}

String formatDueFromMillis(int dueMillis, int nowMillis) {
  if (dueMillis <= 0 || dueMillis <= nowMillis) return 'Ready now';
  return 'in ${formatDurationShort(Duration(milliseconds: dueMillis - nowMillis))}';
}

String formatDueFromDate(DateTime due, DateTime now) {
  final diff = due.difference(now);
  if (diff.isNegative) return 'Ready now';
  return 'in ${formatDurationShort(diff)}';
}

String formatDateTimeYmdHm(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

int dayKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
