import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../core/models.dart' hide integer;

part 'app_database.g.dart';

class QuotaSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get bucketId => text()();
  TextColumn get bucketName => text()();
  TextColumn get windowType => text()();
  IntColumn get windowDurationSeconds => integer().nullable()();
  RealColumn get usedPercent => real().nullable()();
  RealColumn get remainingPercent => real().nullable()();
  DateTimeColumn get resetAt => dateTime().nullable()();
  TextColumn get planType => text().nullable()();
}

class ActivityEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get type => text()();
  TextColumn get bucketId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  RealColumn get oldValue => real().nullable()();
  RealColumn get newValue => real().nullable()();
}

@DriftDatabase(tables: [QuotaSnapshots, ActivityEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'codex_monitor'));
  AppDatabase.forTesting(super.e);
  @override
  int get schemaVersion => 1;

  Future<void> saveUsage(CodexUsageResponse usage, DateTime at) async {
    await transaction(() async {
      Future<void> add(String id, String name, CodexRateLimit limit) async {
        for (var i = 0; i < limit.windows.length; i++) {
          final win = limit.windows[i];
          if (win.usedPercent == null && win.durationSeconds == null) continue;
          final previous =
              await (select(quotaSnapshots)
                    ..where(
                      (t) =>
                          t.bucketId.equals(id) &
                          t.windowDurationSeconds.equalsNullable(
                            win.durationSeconds,
                          ),
                    )
                    ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
                    ..limit(1))
                  .getSingleOrNull();
          await into(quotaSnapshots).insert(
            QuotaSnapshotsCompanion.insert(
              timestamp: at.toUtc(),
              bucketId: id,
              bucketName: name,
              windowType: i == 0 ? 'primary' : 'secondary',
              windowDurationSeconds: Value(win.durationSeconds),
              usedPercent: Value(win.usedPercent),
              remainingPercent: Value(win.remainingPercent),
              resetAt: Value(win.resetAt?.toUtc()),
              planType: Value(usage.planType),
            ),
          );
          if (previous == null || previous.usedPercent != win.usedPercent) {
            final reset =
                previous != null &&
                previous.usedPercent != null &&
                win.usedPercent != null &&
                previous.usedPercent! >= 90 &&
                win.usedPercent! <= 10 &&
                previous.resetAt != win.resetAt;
            await into(activityEvents).insert(
              ActivityEventsCompanion.insert(
                timestamp: at.toUtc(),
                type: reset ? 'reset' : 'quota_change',
                bucketId: Value(id),
                title: reset ? '额度窗口已重置' : '$name 额度更新',
                description: reset
                    ? '$name ${windowLabel(win.durationSeconds)}窗口已重置'
                    : '$name 剩余额度更新为 ${win.remainingPercent?.round() ?? '--'}%',
                oldValue: Value(previous?.usedPercent),
                newValue: Value(win.usedPercent),
              ),
            );
          }
        }
      }

      await add('main', 'Codex 主额度', usage.rateLimit);
      for (final item in usage.additional) {
        await add(
          item.feature ?? item.name ?? 'additional',
          item.displayName,
          item.rateLimit,
        );
      }
      await (delete(quotaSnapshots)..where(
            (t) => t.timestamp.isSmallerThanValue(
              DateTime.now().toUtc().subtract(const Duration(days: 60)),
            ),
          ))
          .go();
    });
  }

  Future<List<QuotaSnapshot>> snapshots(
    Duration range, {
    String bucketId = 'main',
  }) =>
      (select(quotaSnapshots)
            ..where(
              (t) =>
                  t.bucketId.equals(bucketId) &
                  // A rate-limit response can carry a short and a long
                  // window. The dashboard history is the live (shortest)
                  // window, not a zig-zag mixture of both series.
                  t.windowType.equals('primary') &
                  t.timestamp.isBiggerOrEqualValue(
                    DateTime.now().toUtc().subtract(range),
                  ),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  /// Reads an explicit chart window. [end] is exclusive, so a sample at the
  /// following midnight belongs to the following day's chart.
  Future<List<QuotaSnapshot>> snapshotsBetween(
    DateTime start,
    DateTime end, {
    String bucketId = 'main',
  }) =>
      (select(quotaSnapshots)
            ..where(
              (t) =>
                  t.bucketId.equals(bucketId) &
                  t.windowType.equals('primary') &
                  t.timestamp.isBiggerOrEqualValue(start.toUtc()) &
                  t.timestamp.isSmallerThanValue(end.toUtc()),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Future<List<ActivityEvent>> recentEvents([int count = 8]) =>
      (select(activityEvents)
            ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
            ..limit(count))
          .get();
  Future<QuotaSnapshot?> lastSnapshot() =>
      (select(quotaSnapshots)
            ..where(
              (t) => t.bucketId.equals('main') & t.windowType.equals('primary'),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
            ..limit(1))
          .getSingleOrNull();
  Future<void> clearHistory() async {
    await transaction(() async {
      await delete(quotaSnapshots).go();
      await delete(activityEvents).go();
    });
  }

  Future<void> addSystemEvent(String type, String title, String description) =>
      into(activityEvents).insert(
        ActivityEventsCompanion.insert(
          timestamp: DateTime.now().toUtc(),
          type: type,
          title: title,
          description: description,
        ),
      );

  /// Deliberately returns aggregate operational metadata only. No auth table
  /// exists in this database, so credentials cannot enter a diagnostic export.
  Future<Map<String, Object?>> diagnosticSummary() async {
    final snapshots = await select(quotaSnapshots).get();
    final events = await select(activityEvents).get();
    final last = snapshots.isEmpty
        ? null
        : snapshots
              .map((s) => s.timestamp)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    return {
      'snapshot_count': snapshots.length,
      'activity_event_count': events.length,
      'last_snapshot_utc': last?.toUtc().toIso8601String(),
      'schema_version': schemaVersion,
    };
  }
}
