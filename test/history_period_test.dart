import 'package:codex_quota_monitor/features/dashboard/history_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('24-hour history is rolling from now into the past', () {
    final now = DateTime(2026, 8, 23, 14, 35);
    final period = rollingHistoryPeriod(const Duration(hours: 24), now);

    expect(period.start, DateTime(2026, 8, 22, 14, 35));
    expect(period.end, now);
    expect(period.kind, HistoryPeriodKind.rolling);
    expect(period.isFixed, isFalse);
  });

  test('seven-day history is also a rolling window', () {
    final now = DateTime(2026, 8, 23, 14, 35);
    final period = rollingHistoryPeriod(const Duration(days: 7), now);

    expect(period.start, DateTime(2026, 8, 16, 14, 35));
    expect(period.end, now);
    expect(period.kind, HistoryPeriodKind.rolling);
  });

  test('every short range ends at now instead of a calendar boundary', () {
    final now = DateTime(2026, 8, 23, 14, 35);
    for (final range in const [
      Duration(hours: 1),
      Duration(hours: 6),
      Duration(hours: 12),
    ]) {
      final period = rollingHistoryPeriod(range, now);
      expect(period.start, now.subtract(range));
      expect(period.end, now);
    }
  });

  test('today spans local 00:00 to the following 00:00', () {
    final now = DateTime(2026, 8, 23, 14, 35);
    final period = todayHistoryPeriod(now);

    expect(period.start, DateTime(2026, 8, 23));
    expect(period.end, DateTime(2026, 8, 24));
    expect(period.observedEnd(now), now);
    expect(period.kind, HistoryPeriodKind.today);
    expect(period.isFixed, isTrue);
  });

  test('refresh cycle follows the GPT duration and reset time', () {
    final resetAt = DateTime(2026, 8, 23, 18);
    final period = refreshCycleHistoryPeriod(
      durationSeconds: 5 * 60 * 60,
      resetAt: resetAt,
    );

    expect(period, isNotNull);
    expect(period!.start, DateTime(2026, 8, 23, 13));
    expect(period.end, resetAt);
    expect(period.kind, HistoryPeriodKind.refreshCycle);
    expect(period.isFixed, isTrue);
  });

  test('refresh cycle is unavailable without service metadata', () {
    expect(
      refreshCycleHistoryPeriod(durationSeconds: null, resetAt: null),
      isNull,
    );
  });

  test('rolling cache identity does not change as the clock advances', () {
    const range = Duration(hours: 24);
    final first = rollingHistoryPeriod(range, DateTime(2026, 8, 23, 14, 35));
    final later = rollingHistoryPeriod(range, DateTime(2026, 8, 23, 14, 36));

    expect(historyCacheKey(first, range), historyCacheKey(later, range));
  });

  test('fixed-period cache identity changes only at its boundary', () {
    const range = Duration(hours: 24);
    final morning = todayHistoryPeriod(DateTime(2026, 8, 23, 8));
    final evening = todayHistoryPeriod(DateTime(2026, 8, 23, 20));
    final tomorrow = todayHistoryPeriod(DateTime(2026, 8, 24, 8));

    expect(historyCacheKey(morning, range), historyCacheKey(evening, range));
    expect(
      historyCacheKey(morning, range),
      isNot(historyCacheKey(tomorrow, range)),
    );
  });
}
