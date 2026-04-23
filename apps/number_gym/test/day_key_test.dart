import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/day_key.dart';

void main() {
  test('formatDayKey uses local YYYY-MM-DD format', () {
    final date = DateTime(2026, 2, 9, 18, 45);

    expect(formatDayKey(date), '2026-02-09');
  });

  test('formatDayKey normalizes utc input to local day before formatting', () {
    final date = DateTime.utc(2026, 2, 9, 18, 45);
    final local = date.toLocal();
    final expected =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';

    expect(formatDayKey(date), expected);
  });
}
