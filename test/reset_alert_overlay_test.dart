import 'package:codex_quota_monitor/app/theme.dart';
import 'package:codex_quota_monitor/core/reset_alert.dart';
import 'package:codex_quota_monitor/features/reset_alert/reset_alert_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final alert = ResetAnnouncement(
    id: 'one',
    resetType: 'regular',
    announcedAt: DateTime.utc(2026, 9, 22, 4, 31),
    scheduledFor: DateTime.utc(2026, 9, 23, 7),
    text: 'Reset announced.',
    sourceUrl: 'https://example.com/post',
    trackerName: 'Codex Resets',
    trackerUrl: 'https://codex-resets.com',
  );

  testWidgets('dialog requires an explicit action and can collapse', (
    tester,
  ) async {
    var collapsed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: monitorTheme(),
        home: ResetAlertOverlay(
          state: ResetAlertState(
            announcements: [alert],
            presentation: ResetAlertPresentation.dialog,
          ),
          onCollapse: () => collapsed = true,
          onShowDetails: () {},
          onForceDismiss: () {},
          child: const Scaffold(body: Text('Dashboard')),
        ),
      ),
    );

    expect(find.text('检测到 Codex 全局重置公告'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reset-alert-modal-barrier')),
      findsOneWidget,
    );
    await tester.tap(find.text('收起并保留水印'));
    expect(collapsed, isTrue);
  });

  testWidgets('watermark overlays the app and reopens details', (tester) async {
    var reopened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: monitorTheme(),
        home: ResetAlertOverlay(
          state: ResetAlertState(
            announcements: [alert],
            presentation: ResetAlertPresentation.watermark,
          ),
          onCollapse: () {},
          onShowDetails: () => reopened = true,
          onForceDismiss: () {},
          child: const Scaffold(body: Text('Dashboard')),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('reset-alert-watermark')), findsOneWidget);
    final badge = find.byKey(const ValueKey('reset-alert-watermark-badge'));
    final badgeSize = tester.getSize(badge);
    expect(badgeSize.width, lessThan(500));
    expect(badgeSize.height, lessThan(100));

    await tester.tapAt(const Offset(20, 300));
    expect(reopened, isFalse);

    await tester.tap(badge);
    expect(reopened, isTrue);
  });
}
