import 'dart:async';

import 'package:codex_quota_monitor/app/reset_alert_controller.dart';
import 'package:codex_quota_monitor/core/reset_alert.dart';
import 'package:codex_quota_monitor/services/reset_alert_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeResetAlertClient implements ResetAlertClient {
  ResetAlertFetchResult result;

  _FakeResetAlertClient(this.result, {this.sourceName = 'Codex Resets'});

  @override
  final String sourceName;

  @override
  Future<ResetAlertFetchResult> fetch({String? etag}) async => result;

  @override
  void close({bool force = false}) {}
}

class _DelayedResetAlertClient implements ResetAlertClient {
  final Completer<ResetAlertFetchResult> response = Completer();

  @override
  String get sourceName => 'Codex Resets';

  @override
  Future<ResetAlertFetchResult> fetch({String? etag}) => response.future;

  @override
  void close({bool force = false}) {}
}

ResetAnnouncement _announcement(
  String id, {
  String trackerName = 'Codex Resets',
  String trackerUrl = 'https://codex-resets.com',
}) => ResetAnnouncement(
  id: id,
  resetType: 'regular',
  announcedAt: DateTime.utc(2026, 9, 22, 4, 31),
  scheduledFor: DateTime.utc(2026, 9, 23, 7),
  text: 'Reset announced.',
  sourceUrl: 'https://example.com/$id',
  trackerName: trackerName,
  trackerUrl: trackerUrl,
);

ProviderContainer _container(_FakeResetAlertClient client) => ProviderContainer(
  overrides: [
    resetAlertClientsProvider.overrideWithValue([client]),
    resetAlertAutoRefreshProvider.overrideWithValue(false),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('dialog collapses to a watermark and restores after restart', () async {
    final client = _FakeResetAlertClient(
      ResetAlertFetchResult(announcement: _announcement('one')),
    );
    var container = _container(client);
    await container.read(resetAlertProvider.future);
    await container.read(resetAlertProvider.notifier).refresh();
    expect(
      container.read(resetAlertProvider).value?.presentation,
      ResetAlertPresentation.dialog,
    );

    await container.read(resetAlertProvider.notifier).collapseToWatermark();
    expect(
      container.read(resetAlertProvider).value?.presentation,
      ResetAlertPresentation.watermark,
    );
    container.dispose();

    container = _container(client);
    addTearDown(container.dispose);
    final restored = await container.read(resetAlertProvider.future);
    expect(restored.announcement?.id, 'one');
    expect(restored.presentation, ResetAlertPresentation.watermark);
  });

  test('force dismissal survives refresh until the alert disappears', () async {
    final client = _FakeResetAlertClient(
      ResetAlertFetchResult(announcement: _announcement('one')),
    );
    final container = _container(client);
    addTearDown(container.dispose);
    await container.read(resetAlertProvider.future);
    final controller = container.read(resetAlertProvider.notifier);
    await controller.refresh();
    await controller.forceDismiss();
    await controller.refresh();
    expect(
      container.read(resetAlertProvider).value?.presentation,
      ResetAlertPresentation.hidden,
    );

    client.result = const ResetAlertFetchResult(announcement: null);
    await controller.refresh();
    expect(container.read(resetAlertProvider).value?.announcement, isNull);

    client.result = ResetAlertFetchResult(announcement: _announcement('two'));
    await controller.refresh();
    expect(
      container.read(resetAlertProvider).value?.presentation,
      ResetAlertPresentation.dialog,
    );
  });

  test('in-flight refresh does not undo a force dismissal', () async {
    final initialClient = _FakeResetAlertClient(
      ResetAlertFetchResult(announcement: _announcement('one')),
    );
    var container = _container(initialClient);
    await container.read(resetAlertProvider.future);
    await container.read(resetAlertProvider.notifier).refresh();
    await container.read(resetAlertProvider.notifier).collapseToWatermark();
    container.dispose();

    final delayedClient = _DelayedResetAlertClient();
    final delayedContainer = ProviderContainer(
      overrides: [
        resetAlertClientsProvider.overrideWithValue([delayedClient]),
        resetAlertAutoRefreshProvider.overrideWithValue(false),
      ],
    );
    await delayedContainer.read(resetAlertProvider.future);
    final controller = delayedContainer.read(resetAlertProvider.notifier);
    final refresh = controller.refresh();

    await controller.forceDismiss();
    delayedClient.response.complete(
      ResetAlertFetchResult(announcement: _announcement('one')),
    );
    await refresh;

    expect(
      delayedContainer.read(resetAlertProvider).value?.presentation,
      ResetAlertPresentation.hidden,
    );

    delayedContainer.dispose();
    final restoredContainer = _container(initialClient);
    addTearDown(restoredContainer.dispose);
    final restored = await restoredContainer.read(resetAlertProvider.future);
    expect(restored.presentation, ResetAlertPresentation.hidden);
  });

  test(
    'sources are merged and removing one does not reopen a hidden alert',
    () async {
      final codexResets = _FakeResetAlertClient(
        ResetAlertFetchResult(announcement: _announcement('one')),
      );
      final betterOpc = _FakeResetAlertClient(
        ResetAlertFetchResult(
          announcement: _announcement(
            'two',
            trackerName: 'BetterOPC',
            trackerUrl: 'https://betteropc.com/ai-products/reset-signals/codex',
          ),
        ),
        sourceName: 'BetterOPC',
      );
      final container = ProviderContainer(
        overrides: [
          resetAlertClientsProvider.overrideWithValue([codexResets, betterOpc]),
          resetAlertAutoRefreshProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      await container.read(resetAlertProvider.future);
      final controller = container.read(resetAlertProvider.notifier);

      await controller.refresh();
      expect(
        container.read(resetAlertProvider).value?.announcements,
        hasLength(2),
      );
      await controller.forceDismiss();

      codexResets.result = const ResetAlertFetchResult(announcement: null);
      await controller.refresh();
      final afterRemoval = container.read(resetAlertProvider).value!;
      expect(afterRemoval.announcements, hasLength(1));
      expect(afterRemoval.presentation, ResetAlertPresentation.hidden);

      betterOpc.result = ResetAlertFetchResult(
        announcement: _announcement(
          'three',
          trackerName: 'BetterOPC',
          trackerUrl: 'https://betteropc.com/ai-products/reset-signals/codex',
        ),
      );
      await controller.refresh();
      expect(
        container.read(resetAlertProvider).value?.presentation,
        ResetAlertPresentation.dialog,
      );
    },
  );
}
