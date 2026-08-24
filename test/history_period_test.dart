import 'package:codex_quota_monitor/features/dashboard/history_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('24-hour history spans the local calendar day', () {
    final period = historyPeriodFor(
      const Duration(hours: 24),
      DateTime(2026, 8, 23, 14, 35),
    );

    expect(period.start, DateTime(2026, 8, 23));
    expect(period.end, DateTime(2026, 8, 24));
    expect(
      period.observedEnd(DateTime(2026, 8, 23, 14, 35)),
      DateTime(2026, 8, 23, 14, 35),
    );
    expect(period.isCalendarBounded, isTrue);
  });

  test('seven-day history follows the server weekly refresh cycle', () {
    final period = historyPeriodFor(
      const Duration(days: 7),
      DateTime(2026, 8, 23, 14, 35), // Sunday
      weeklyResetAt: DateTime(2026, 8, 27, 7), // Wednesday 07:00
    );

    expect(period.start, DateTime(2026, 8, 20, 7));
    expect(period.end, DateTime(2026, 8, 27, 7));
    expect(period.isCalendarBounded, isTrue);
  });

  test(
    'seven-day history falls back to a rolling window without reset data',
    () {
      final now = DateTime(2026, 8, 23, 14, 35);
      final period = historyPeriodFor(const Duration(days: 7), now);

      expect(period.start, DateTime(2026, 8, 16, 14, 35));
      expect(period.end, now);
      expect(period.isCalendarBounded, isFalse);
    },
  );

  test('other ranges remain rolling windows', () {
    final now = DateTime(2026, 8, 23, 14, 35);
    final period = historyPeriodFor(const Duration(hours: 6), now);

    expect(period.start, DateTime(2026, 8, 23, 8, 35));
    expect(period.end, now);
    expect(period.isCalendarBounded, isFalse);
  });
}
