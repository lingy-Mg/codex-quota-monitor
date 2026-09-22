import 'package:codex_quota_monitor/services/better_opc_reset_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the scheduled reset embedded in BetterOPC HTML', () {
    final service = BetterOpcResetService();
    addTearDown(service.close);
    const html = r'''
      <li class="product-tracking-signal product-tracking-scheduled-reset"
          data-signal-id="event-1" data-scheduled-countdown="true">
        <span data-signal-reset-status="scheduled">已排期</span>
        <p class="product-tracking-scheduled-reset-evidence">
          作者已给出明确执行时间
        </p>
        <a href="https://x.com/thsottiaux/status/123">查看原文</a>
      </li>
      <script>
        self.__next_f.push([1,"targetIso\":\"2026-09-22T10:00:00.000Z\",
        publishedAtIso\":\"2026-09-19T16:48:38.000Z\""])
      </script>
    ''';

    final result = service.parse(html);

    expect(result?.id, 'event-1');
    expect(result?.trackerName, 'BetterOPC');
    expect(result?.scheduledFor, DateTime.utc(2026, 9, 22, 10));
    expect(result?.announcedAt, DateTime.utc(2026, 9, 19, 16, 48, 38));
    expect(result?.sourceUrl, 'https://x.com/thsottiaux/status/123');
    expect(result?.text, '作者已给出明确执行时间');
  });

  test('returns no alert when the scheduled marker is absent', () {
    final service = BetterOpcResetService();
    addTearDown(service.close);

    expect(service.parse('<html>今日无重置</html>'), isNull);
  });
}
