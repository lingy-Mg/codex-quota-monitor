import 'dart:io';

import 'package:codex_quota_monitor/core/models.dart';
import 'package:codex_quota_monitor/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'diagnostic summary is aggregate metadata without credential fields',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final summary = await database.diagnosticSummary();
      expect(summary['snapshot_count'], 0);
      expect(summary['activity_event_count'], 0);
      expect(summary.keys, isNot(contains('access_token')));
      expect(summary.keys, isNot(contains('refresh_token')));
      expect(summary.keys, isNot(contains('account_id')));
    },
  );

  test('quota snapshots survive reopening the local database', () async {
    final directory = await Directory.systemTemp.createTemp('codex-monitor-');
    final databaseFile = File(
      '${directory.path}${Platform.pathSeparator}quota',
    );
    addTearDown(() => directory.delete(recursive: true));

    final written = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final current = DateTime.now().toUtc();
    final second = DateTime.utc(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
      current.second,
    );
    final first = second.subtract(const Duration(minutes: 1));
    final usage = CodexUsageResponse.fromJson({
      'plan_type': 'prolite',
      'rate_limit': {
        'primary_window': {'used_percent': 38, 'limit_window_seconds': 604800},
      },
    });

    await written.saveUsage(usage, first);
    await written.saveUsage(usage, second);
    await written.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(reopened.close);
    final snapshots = await reopened.snapshots(const Duration(hours: 1));

    expect(snapshots, hasLength(2));
    expect(snapshots.map((row) => row.remainingPercent), everyElement(62));
    expect(
      snapshots.map((row) => row.timestamp.toUtc()),
      orderedEquals([first, second]),
    );
  });

  test('history reads only the live quota window', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.saveUsage(
      CodexUsageResponse.fromJson({
        'rate_limit': {
          'primary_window': {
            'used_percent': 20,
            'limit_window_seconds': 604800,
          },
          'secondary_window': {
            'used_percent': 45,
            'limit_window_seconds': 18000,
          },
        },
      }),
      DateTime.now().toUtc(),
    );

    final history = await database.snapshots(const Duration(hours: 1));

    expect(history, hasLength(1));
    expect(history.single.remainingPercent, 55);
  });

  test(
    'calendar history query includes its start and excludes its end',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final usage = CodexUsageResponse.fromJson({
        'rate_limit': {
          'primary_window': {'used_percent': 20, 'limit_window_seconds': 18000},
        },
      });
      final start = DateTime.utc(2026, 8, 23);
      await database.saveUsage(usage, start);
      await database.saveUsage(usage, start.add(const Duration(hours: 12)));
      await database.saveUsage(usage, start.add(const Duration(days: 1)));

      final history = await database.snapshotsBetween(
        start,
        start.add(const Duration(days: 1)),
      );

      expect(history, hasLength(2));
      expect(
        history.map((row) => row.timestamp.toUtc()),
        orderedEquals([start, start.add(const Duration(hours: 12))]),
      );
    },
  );
}
