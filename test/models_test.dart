import 'package:flutter_test/flutter_test.dart';
import 'package:codex_quota_monitor/core/models.dart';

void main() {
  group('usage response parsing', () {
    test(
      'used percent is converted to remaining percent and windows are sorted',
      () {
        final usage = CodexUsageResponse.fromJson({
          'plan_type': 'prolite',
          'rate_limit': {
            'primary_window': {
              'used_percent': 32,
              'limit_window_seconds': 604800,
            },
            'secondary_window': {
              'used_percent': 58,
              'limit_window_seconds': 18000,
            },
          },
          'additional_rate_limits': [
            {
              'limit_name': 'GPT-5.3-Codex-Spark',
              'rate_limit': {
                'primary_window': {
                  'used_percent': 17,
                  'limit_window_seconds': 18000,
                },
              },
            },
          ],
          'credits': {'has_credits': true, 'balance': '12.50'},
          'rate_limit_reset_credits': {'available_count': 2},
        });
        expect(usage.planType, 'prolite');
        expect(usage.rateLimit.windows.first.remainingPercent, 42);
        expect(usage.rateLimit.windows.last.remainingPercent, 68);
        expect(usage.additional.single.displayName, 'Codex Spark');
        expect(usage.resetCredits, 2);
      },
    );
    test('nullable and unknown fields never create fabricated values', () {
      final u = CodexUsageResponse.fromJson({
        'plan_type': 'enterprise_x',
        'rate_limit': {},
        'credits': {'unlimited': true},
      });
      expect(u.planType, 'enterprise_x');
      expect(u.rateLimit.windows, isEmpty);
      expect(u.credits!.balance, isNull);
      expect(u.credits!.unlimited, isTrue);
    });
    test('an empty server window does not create a quota card', () {
      final u = CodexUsageResponse.fromJson({
        'rate_limit': {
          'primary_window': {
            'used_percent': 37,
            'limit_window_seconds': 604800,
          },
          'secondary_window': <String, dynamic>{},
        },
      });
      expect(u.rateLimit.windows, hasLength(1));
      expect(u.rateLimit.windows.single.remainingPercent, 63);
    });
    test('clamps malformed percentages', () {
      expect(RateWindow.fromJson({'used_percent': -10}).remainingPercent, 100);
      expect(RateWindow.fromJson({'used_percent': 120}).remainingPercent, 0);
    });
    test('reports the unelapsed portion of a window separately from quota', () {
      final resetAt = DateTime.utc(2026, 8, 24, 12);
      final window = RateWindow(
        usedPercent: 63,
        durationSeconds: const Duration(days: 7).inSeconds,
        resetAt: resetAt,
      );
      expect(
        window.timeRemainingPercent(resetAt.subtract(const Duration(days: 4))),
        closeTo(57.14, .01),
      );
      expect(
        window.timeRemainingPercent(resetAt.add(const Duration(minutes: 1))),
        0,
      );
    });
  });
  test('auth json requires all credential fields', () {
    expect(
      () => CodexCredentials.fromAuthJson('{"tokens":{"access_token":"a"}}'),
      throwsFormatException,
    );
    expect(
      CodexCredentials.fromAuthJson(
        '{"tokens":{"access_token":"a","refresh_token":"b","account_id":"c"}}',
      ).accountId,
      'c',
    );
  });
}
