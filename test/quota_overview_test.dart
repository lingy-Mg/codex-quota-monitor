import 'package:codex_quota_monitor/app/theme.dart';
import 'package:codex_quota_monitor/core/models.dart';
import 'package:codex_quota_monitor/features/dashboard/quota_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all extra quotas and earliest reset expiry are visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 9, 15, 12);
    final usage = CodexUsageResponse(
      rateLimit: CodexRateLimit(
        primary: RateWindow(
          usedPercent: 25,
          durationSeconds: 18000,
          resetAt: now.add(const Duration(hours: 2)),
        ),
        secondary: RateWindow(
          usedPercent: 53,
          durationSeconds: 604800,
          resetAt: now.add(const Duration(days: 5)),
        ),
      ),
      additional: [
        AdditionalLimit(
          name: 'GPT-5.3-Codex-Spark',
          rateLimit: CodexRateLimit(
            primary: RateWindow(
              usedPercent: 17,
              durationSeconds: 18000,
              resetAt: now.add(const Duration(hours: 2)),
            ),
            secondary: RateWindow(
              usedPercent: 30,
              durationSeconds: 604800,
              resetAt: now.add(const Duration(days: 7)),
            ),
          ),
        ),
        AdditionalLimit(
          name: 'gpt-reserve',
          rateLimit: CodexRateLimit(
            primary: RateWindow(usedPercent: 8, durationSeconds: 604800),
          ),
        ),
      ],
      resetCredits: 3,
      resetCards: [
        ResetCredit(expiresAt: now.add(const Duration(days: 120))),
        ResetCredit(expiresAt: now.add(const Duration(days: 8))),
        ResetCredit(expiresAt: now.add(const Duration(days: 2))),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: monitorTheme(),
        home: Scaffold(
          body: QuotaOverview(
            usage: usage,
            now: now,
            stale: false,
            gap: 12,
            onExpired: () {},
          ),
        ),
      ),
    );
    expect(find.text('附加额度 · Codex Spark'), findsOneWidget);
    expect(find.text('GPT Reserve'), findsOneWidget);
    expect(find.text('83%'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.byKey(const ValueKey('quota-secondary-label')), findsOneWidget);
    expect(find.textContaining('剩余 47%'), findsOneWidget);
    expect(find.byKey(const ValueKey('quota-secondary-track')), findsOneWidget);
    expect(find.textContaining('7天周期 · 剩余 70%'), findsOneWidget);
    expect(find.text('2026-09-17'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
    expect(find.text('120'), findsNothing);
    final first = tester.getRect(find.byKey(const ValueKey('reset-ticket-0')));
    final second = tester.getRect(find.byKey(const ValueKey('reset-ticket-1')));
    final third = tester.getRect(find.byKey(const ValueKey('reset-ticket-2')));
    expect(first.top, second.top);
    expect(second.top, third.top);
    expect(first.right, lessThan(second.left));
    expect(second.right, lessThan(third.left));
    expect(third.right, lessThanOrEqualTo(1280));
    expect(find.text('02'), findsOneWidget);
    expect(find.text('08'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('02')).dx,
      lessThan(tester.getTopLeft(find.text('08')).dx),
    );
    expect(
      tester.getTopLeft(find.text('2026-09-17')).dy,
      greaterThan(tester.getBottomLeft(find.text('02')).dy),
    );
    final start = tester.getTopLeft(
      find.byKey(const ValueKey('quota-track-segment-1-0')),
    );
    final end = tester.getTopRight(
      find.byKey(const ValueKey('quota-track-segment-1-0')),
    );
    expect(end.dx - start.dx, greaterThan(800));
    expect(find.byKey(const ValueKey('quota-track-segment-7-0')), findsNothing);
    expect(find.bySemanticsLabel('上层剩余额度 75%，下层剩余时间 40%'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      final track = find.byKey(ValueKey('additional-track-$i'));
      expect(tester.getSize(track).width, closeTo(end.dx - start.dx, 1));
      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(of: track, matching: find.byType(FractionallySizedBox)),
      );
      expect(fill.widthFactor, closeTo(i == 0 ? .83 : .92, .001));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('expiry states and extra tickets remain accessible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 230));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 9, 15, 12);
    await tester.pumpWidget(
      MaterialApp(
        theme: monitorTheme(),
        home: Scaffold(
          body: QuotaOverview(
            usage: CodexUsageResponse(
              rateLimit: const CodexRateLimit(),
              additional: const [],
              resetCredits: 4,
              credits: const CodexCredits(unlimited: true),
              resetCards: [
                const ResetCredit(),
                ResetCredit(expiresAt: now.add(const Duration(hours: 3))),
                ResetCredit(expiresAt: now.subtract(const Duration(days: 1))),
                ResetCredit(
                  expiresAt: now.add(const Duration(days: 8)),
                  supportedByPlan: false,
                ),
              ],
            ),
            now: now,
            stale: true,
            gap: 12,
            onExpired: () {},
          ),
        ),
      ),
    );
    expect(find.text('已到期'), findsOneWidget);
    expect(find.text('今日到期'), findsOneWidget);
    expect(find.text('当前套餐不支持'), findsOneWidget);
    expect(find.text('Unlimited'), findsOneWidget);
    expect(find.text('暂无附加额度'), findsOneWidget);
    expect(find.byKey(const ValueKey('quota-secondary-label')), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('reset-ticket-list')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('到期未知').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly main quota stays primary when no short window exists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 9, 15, 12);
    await tester.pumpWidget(
      MaterialApp(
        theme: monitorTheme(),
        home: Scaffold(
          body: QuotaOverview(
            usage: const CodexUsageResponse(
              rateLimit: CodexRateLimit(
                primary: RateWindow(usedPercent: 60, durationSeconds: 604800),
              ),
              additional: [],
            ),
            now: now,
            stale: false,
            gap: 12,
            onExpired: () {},
          ),
        ),
      ),
    );

    expect(find.text('周周期'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.byKey(const ValueKey('quota-secondary-label')), findsNothing);
    expect(
      find.byKey(const ValueKey('quota-track-segment-7-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('quota-track-segment-7-6')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('quota fill animates between refreshed values', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 9, 15, 12);
    Widget buildWithRemaining(double remaining) => MaterialApp(
      theme: monitorTheme(),
      home: Scaffold(
        body: QuotaOverview(
          usage: CodexUsageResponse(
            rateLimit: CodexRateLimit(
              primary: RateWindow(
                usedPercent: 100 - remaining,
                durationSeconds: 18000,
                resetAt: now.add(const Duration(hours: 2)),
              ),
            ),
            additional: const [],
          ),
          now: now,
          stale: false,
          gap: 12,
          onExpired: () {},
        ),
      ),
    );

    await tester.pumpWidget(buildWithRemaining(80));
    final fill = find.descendant(
      of: find.byKey(const ValueKey('quota-track-segment-1-0')),
      matching: find.byType(FractionallySizedBox),
    );
    expect(
      tester.widget<FractionallySizedBox>(fill).widthFactor,
      closeTo(.8, .001),
    );

    await tester.pumpWidget(buildWithRemaining(20));
    await tester.pump(const Duration(milliseconds: 1200));
    final halfway = tester.widget<FractionallySizedBox>(fill).widthFactor!;
    expect(halfway, lessThan(.8));
    expect(halfway, greaterThan(.2));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(
      tester.widget<FractionallySizedBox>(fill).widthFactor,
      closeTo(.2, .001),
    );
    expect(tester.takeException(), isNull);
  });
}
