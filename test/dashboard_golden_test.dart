import 'package:codex_quota_monitor/app/monitor_controller.dart';
import 'package:codex_quota_monitor/app/theme.dart';
import 'package:codex_quota_monitor/core/models.dart';
import 'package:codex_quota_monitor/database/app_database.dart';
import 'package:codex_quota_monitor/features/dashboard/dashboard_page.dart';
import 'package:codex_quota_monitor/services/device_service.dart';
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardState preview() => DashboardState(
  health: MonitorHealth.live,
  lastSync: DateTime(2026, 8, 23, 15, 40),
  device: DeviceStatus(
    uptime: const Duration(hours: 12),
    charging: true,
    full: false,
    memoryMb: 128.4,
  ),
  usage: CodexUsageResponse.fromJson(
    {
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
            'primary_window': {
              'used_percent': 17,
              'limit_window_seconds': 18000,
            },
            'secondary_window': {
              'used_percent': 38,
              'limit_window_seconds': 604800,
            },
          },
        },
        {
          'limit_name': 'gpt-reserve',
          'rate_limit': {
            'primary_window': {
              'used_percent': 8,
              'limit_window_seconds': 604800,
            },
          },
        },
      ],
      'credits': {'has_credits': true, 'balance': '12.50'},
      'rate_limit_reset_credits': {'available_count': 3},
    },
    resetDetails: {
      'available_count': 3,
      'credits': [
        {'status': 'available', 'expires_at': '2026-06-06T12:00:00Z'},
        {'status': 'available', 'expires_at': '2026-10-06T12:00:00Z'},
        {'status': 'available', 'expires_at': '2026-05-29T12:00:00Z'},
      ],
    },
  ),
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
                    const Duration(hours: 2, minutes: 44, seconds: 37),
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
    final overviewBottom = tester.getBottomLeft(find.text('GPT Reserve')).dy;
    final reserveTrack = tester.getRect(
      find.byKey(const ValueKey('additional-track-1')),
    );
    expect(reserveTrack.top, greaterThan(overviewBottom));
    expect(
      reserveTrack.bottom,
      lessThan(
        tester.getBottomLeft(find.byKey(const ValueKey('reset-ticket-2'))).dy +
            14,
      ),
    );
    final thirdTicket = tester.getRect(
      find.byKey(const ValueKey('reset-ticket-2')),
    );
    expect(thirdTicket.right, lessThanOrEqualTo(640));
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

  testWidgets('24-hour history is rolling and has readable bottom ticks', (
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
    expect(
      chart.data.minX,
      now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch,
    );
    expect(chart.data.maxX, now.millisecondsSinceEpoch);
    expect(chart.data.titlesData.bottomTitles.sideTitles.showTitles, isTrue);
    expect(
      chart.data.titlesData.bottomTitles.sideTitles.interval,
      const Duration(hours: 4).inMilliseconds,
    );
    expect(
      chart.data.lineBarsData,
      anyElement((line) => line.dashArray != null),
    );
    expect(
      chart.data.lineBarsData,
      anyElement((line) => line.dashArray == null),
    );
  });

  testWidgets('today and refresh cycle are separate fixed periods', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 8, 23, 14, 35);
    final resetAt = now.add(const Duration(hours: 3));
    final usage = CodexUsageResponse.fromJson({
      'rate_limit': {
        'primary_window': {
          'used_percent': 38,
          'limit_window_seconds': 5 * 60 * 60,
          'reset_at': resetAt.millisecondsSinceEpoch ~/ 1000,
        },
      },
    });
    await db.saveUsage(usage, now.subtract(const Duration(minutes: 5)));
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

    expect(find.text('12小时'), findsOneWidget);
    await tester.tap(find.text('今天'));
    await tester.pump(const Duration(milliseconds: 100));
    var chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, DateTime(2026, 8, 23).millisecondsSinceEpoch);
    expect(chart.data.maxX, DateTime(2026, 8, 24).millisecondsSinceEpoch);

    await tester.tap(find.text('刷新周期内'));
    await tester.pump(const Duration(milliseconds: 100));
    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(
      chart.data.minX,
      resetAt.subtract(const Duration(hours: 5)).millisecondsSinceEpoch,
    );
    expect(chart.data.maxX, resetAt.millisecondsSinceEpoch);
  });

  testWidgets('history renders a labelled purple trend forecast', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 8, 24, 14);
    final resetAt = now.add(const Duration(hours: 4));
    CodexUsageResponse usage(int usedPercent) => CodexUsageResponse.fromJson({
      'rate_limit': {
        'primary_window': {
          'used_percent': usedPercent,
          'limit_window_seconds': 18000,
          'reset_at': resetAt.millisecondsSinceEpoch ~/ 1000,
        },
      },
    });
    for (var minute = 30; minute >= 5; minute -= 5) {
      await db.saveUsage(
        usage(20 + (30 - minute) ~/ 5),
        now.subtract(Duration(minutes: minute)),
      );
    }
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
              usage: usage(26),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('刷新周期内'));
    await tester.pump(const Duration(milliseconds: 100));

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(
      chart.data.lineBarsData,
      anyElement((line) => line.color == AppColors.purple),
    );
    expect(find.textContaining('趋势预测'), findsOneWidget);

    final historyBar = chart.data.lineBarsData.firstWhere(
      (line) => line.color != AppColors.purple && line.spots.isNotEmpty,
    );
    final tooltipItems = chart.data.lineTouchData.touchTooltipData
        .getTooltipItems([LineBarSpot(historyBar, 0, historyBar.spots.first)]);
    expect(tooltipItems.single?.text, contains('记录时间'));
    expect(tooltipItems.single?.text, contains('剩余'));

    final touchCallback = chart.data.lineTouchData.touchCallback;
    expect(touchCallback, isNotNull);
    touchCallback!(
      FlTapUpEvent(
        TapUpDetails(localPosition: Offset.zero, kind: PointerDeviceKind.touch),
      ),
      LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset.zero,
        lineBarSpots: [
          TouchLineBarSpot(historyBar, 0, historyBar.spots.first, 0),
        ],
      ),
    );
    await tester.pump();
    expect(find.textContaining('记录 08-24'), findsOneWidget);
  });
}
