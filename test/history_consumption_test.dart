import 'package:codex_quota_monitor/core/history_consumption.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 25, 10);
  final reset = DateTime(2026, 9, 25, 15);

  HistoryUsageObservation row(int minutes, double used, {DateTime? resetAt}) =>
      (
        timestamp: start.add(Duration(minutes: minutes)),
        usedPercent: used,
        resetAt: resetAt ?? reset,
        windowDurationSeconds: 18000,
      );

  test('consumption adds changes within each clock hour', () {
    final buckets = historyConsumptionBuckets(
      [row(50, 10), row(55, 12), row(60, 13), row(65, 15)],
      start: start,
      end: start.add(const Duration(hours: 2)),
      unit: historyConsumptionUnit,
    );
    expect(buckets.map((b) => b.consumedPercent), [2, 3]);
    expect(buckets.first.timestamp, start);
    expect(buckets.last.timestamp, start.add(const Duration(hours: 1)));
  });

  test('resets and offline gaps do not invent consumption', () {
    final buckets = historyConsumptionBuckets(
      [
        row(0, 40),
        row(2, 41),
        row(4, 5, resetAt: reset.add(const Duration(hours: 5))),
        row(6, 6, resetAt: reset.add(const Duration(hours: 5))),
        row(30, 10, resetAt: reset.add(const Duration(hours: 5))),
      ],
      start: start,
      end: start.add(const Duration(hours: 1)),
      unit: historyConsumptionUnit,
    );
    expect(buckets.map((b) => b.consumedPercent), [2]);
  });

  test('time unit is one hour and maximum follows actual use', () {
    expect(historyConsumptionUnit, const Duration(hours: 1));
    expect(historyConsumptionAxisMax([0, .2]), .5);
    expect(historyConsumptionAxisMax([2.5, 3]), 5);
    expect(historyPercentLabel(.25), '0.25%');
  });

  test('hourly buckets align with the local clock hour', () {
    final buckets = historyConsumptionBuckets(
      [row(239, 10), row(241, 12)],
      start: start,
      end: start.add(const Duration(hours: 6)),
      unit: historyConsumptionUnit,
    );
    expect(buckets.single.timestamp, DateTime(2026, 9, 25, 14));
    expect(buckets.single.consumedPercent, 2);
  });
}
