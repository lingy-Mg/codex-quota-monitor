import 'package:codex_quota_monitor/features/dashboard/remaining_quota_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RemainingQuotaObservation point(
    DateTime timestamp,
    double remaining, {
    DateTime? resetAt,
  }) => RemainingQuotaObservation(
    timestamp: timestamp,
    remainingPercent: remaining,
    resetAt: resetAt,
  );

  test(
    'uses a half-day history to make a conservative full-period forecast',
    () {
      final start = DateTime(2026, 8, 24, 8);
      final resetAt = DateTime(2026, 8, 24, 18);
      final observations = [
        for (var minute = 0; minute <= 5 * 60; minute += 5)
          point(
            start.add(Duration(minutes: minute)),
            92 - minute / 20,
            resetAt: resetAt,
          ),
      ];

      final forecast = forecastRemainingQuota(
        observations,
        asOf: DateTime(2026, 8, 24, 13),
        periodEnd: DateTime(2026, 8, 25),
      );

      expect(forecast, isNotNull);
      expect(forecast!.start, DateTime(2026, 8, 24, 13));
      expect(forecast.end, DateTime(2026, 8, 25));
      expect(forecast.percentPointsPerHour, closeTo(-3, .01));
      expect(forecast.endPercent, lessThan(92));
    },
  );

  test('uses only the current reset cycle to project the requested period', () {
    final start = DateTime(2026, 8, 24, 8);
    final resetAt = DateTime(2026, 8, 24, 16);
    final observations = [
      point(start, 12, resetAt: DateTime(2026, 8, 24, 10)),
      point(
        start.add(const Duration(hours: 1)),
        8,
        resetAt: DateTime(2026, 8, 24, 10),
      ),
      point(start.add(const Duration(hours: 2)), 94, resetAt: resetAt),
      point(
        start.add(const Duration(hours: 2, minutes: 5)),
        93,
        resetAt: resetAt,
      ),
      point(
        start.add(const Duration(hours: 2, minutes: 10)),
        92,
        resetAt: resetAt,
      ),
      point(
        start.add(const Duration(hours: 2, minutes: 15)),
        91,
        resetAt: resetAt,
      ),
      point(
        start.add(const Duration(hours: 2, minutes: 20)),
        90,
        resetAt: resetAt,
      ),
      point(
        start.add(const Duration(hours: 2, minutes: 25)),
        89,
        resetAt: resetAt,
      ),
    ];

    final forecast = forecastRemainingQuota(
      observations,
      asOf: start.add(const Duration(hours: 2, minutes: 25)),
      periodEnd: DateTime(2026, 8, 25),
    );

    expect(forecast, isNotNull);
    expect(forecast!.startPercent, 89);
    expect(forecast.end, DateTime(2026, 8, 25));
    expect(forecast.endPercent, lessThan(89));
  });

  test('hides a forecast when there is no clear consumption trend', () {
    final start = DateTime(2026, 8, 24, 8);
    final observations = [
      for (var minute = 0; minute <= 20; minute += 5)
        point(start.add(Duration(minutes: minute)), 76),
    ];

    expect(
      forecastRemainingQuota(
        observations,
        asOf: start.add(const Duration(minutes: 20)),
        periodEnd: DateTime(2026, 8, 25),
      ),
      isNull,
    );
  });

  test('keeps continuous samples when reset timestamps drift slightly', () {
    final start = DateTime(2026, 8, 24, 12);
    final observations = [
      for (var minute = 0; minute <= 25; minute += 5)
        point(
          start.add(Duration(minutes: minute)),
          90 - minute / 5,
          resetAt: DateTime(2026, 8, 24, 18, minute),
        ),
    ];

    final forecast = forecastRemainingQuota(
      observations,
      asOf: start.add(const Duration(minutes: 25)),
      periodEnd: DateTime(2026, 8, 25),
    );

    expect(forecast, isNotNull);
    expect(forecast!.startPercent, 85);
  });
}
