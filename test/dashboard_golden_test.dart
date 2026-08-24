import 'package:codex_quota_monitor/app/monitor_controller.dart';
import 'package:codex_quota_monitor/app/theme.dart';
import 'package:codex_quota_monitor/core/models.dart';
import 'package:codex_quota_monitor/database/app_database.dart';
import 'package:codex_quota_monitor/features/dashboard/dashboard_page.dart';
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardState preview() => DashboardState(
  health: MonitorHealth.live,
  lastSync: DateTime(2026, 8, 23, 15, 40),
  usage: CodexUsageResponse.fromJson({
    'plan_type': 'pro',
    'rate_limit': {
      'primary_window': {
        'used_percent': 32,
        'limit_window_seconds': 18000,
        'reset_at': 1780000000,
      },
      'secondary_window': {
        'used_percent': 58,
        'limit_window_seconds': 604800,
        'reset_at': 1780500000,
      },
    },
    'additional_rate_limits': [
      {
        'limit_name': 'GPT-5.3-Codex-Spark',
        'rate_limit': {
          'primary_window': {'used_percent': 17, 'limit_window_seconds': 18000},
        },
      },
    ],
    'credits': {'has_credits': true, 'balance': '12.50'},
    'rate_limit_reset_credits': {'available_count': 2},
  }),
);
void main() {
  for (final size in const [
    Size(1280, 800),
    Size(1440, 1080),
    Size(1920, 1200),
  ]) {
    testWidgets('dashboard ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: monitorTheme(),
            home: DashboardPage(
              preview: preview(),
              now: () =>
                  DateTime.fromMillisecondsSinceEpoch(
                    1780000000 * 1000,
                    isUtc: true,
                  ).toLocal().subtract(
                    const Duration(hours: 96, minutes: 44, seconds: 37),
                  ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(DashboardPage),
        matchesGoldenFile(
          'goldens/dashboard_${size.width.toInt()}x${size.height.toInt()}.png',
        ),
      );
    });
  }

  testWidgets('compact monitor canvas has no render overflow', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: monitorTheme(),
          home: DashboardPage(
            preview: preview(),
            now: () => DateTime.utc(2026, 5, 26, 12),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history keeps the current chart visible while switching ranges',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now();
      final usage = CodexUsageResponse.fromJson({
        'rate_limit': {
          'primary_window': {'used_percent': 38, 'limit_window_seconds': 18000},
        },
      });
      await db.saveUsage(usage, now.subtract(const Duration(hours: 2)));
      await db.saveUsage(usage, now.subtract(const Duration(minutes: 5)));
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: monitorTheme(),
            home: DashboardPage(preview: preview()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LineChart), findsOneWidget);

      await tester.tap(find.text('6小时'));
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('暂无已记录的额度数据'), findsNothing);
    },
  );

  testWidgets('24-hour history keeps its full-day axis and future dashes', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 8, 23, 14, 35);
    final usage = CodexUsageResponse.fromJson({
      'rate_limit': {
        'primary_window': {'used_percent': 38, 'limit_window_seconds': 18000},
      },
    });
    await db.saveUsage(usage, now.subtract(const Duration(minutes: 5)));
    await db.saveUsage(usage, now.subtract(const Duration(minutes: 1)));
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: monitorTheme(),
          home: DashboardPage(
            now: () => now,
            preview: DashboardState(
              health: MonitorHealth.live,
              lastSync: now,
              usage: usage,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, DateTime(2026, 8, 23).millisecondsSinceEpoch);
    expect(chart.data.maxX, DateTime(2026, 8, 24).millisecondsSinceEpoch);
    expect(
      chart.data.lineBarsData,
      anyElement((line) => line.dashArray != null),
    );
    expect(
      chart.data.lineBarsData,
      anyElement((line) => line.dashArray == null),
    );
  });
}
