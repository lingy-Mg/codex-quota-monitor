enum HistoryPeriodKind { rolling, today, refreshCycle }

/// The explicit time boundary displayed by a quota-history chart.
class HistoryPeriod {
  const HistoryPeriod({
    required this.start,
    required this.end,
    required this.kind,
  });

  final DateTime start;
  final DateTime end;
  final HistoryPeriodKind kind;

  bool get isFixed => kind != HistoryPeriodKind.rolling;

  /// The part of this period for which a real observation could exist.
  DateTime observedEnd(DateTime now) => now.isBefore(end) ? now : end;
}

/// A rolling window always means "from [range] ago until now".
HistoryPeriod rollingHistoryPeriod(Duration range, DateTime now) =>
    HistoryPeriod(
      start: now.subtract(range),
      end: now,
      kind: HistoryPeriodKind.rolling,
    );

/// Today is the local calendar day from 00:00 until the following 00:00.
HistoryPeriod todayHistoryPeriod(DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  return HistoryPeriod(
    start: start,
    end: start.add(const Duration(days: 1)),
    kind: HistoryPeriodKind.today,
  );
}

/// The current GPT quota cycle is defined only by the service-provided
/// duration and reset time. Returning null keeps missing metadata explicit.
HistoryPeriod? refreshCycleHistoryPeriod({
  required int? durationSeconds,
  required DateTime? resetAt,
}) {
  if (durationSeconds == null || durationSeconds <= 0 || resetAt == null) {
    return null;
  }
  final localResetAt = resetAt.toLocal();
  return HistoryPeriod(
    start: localResetAt.subtract(Duration(seconds: durationSeconds)),
    end: localResetAt,
    kind: HistoryPeriodKind.refreshCycle,
  );
}

/// Cache identity follows the user's logical selection, not the current clock.
/// A rolling period moves on every refresh, so including its exact boundaries
/// would retain a new history list forever.
String historyCacheKey(HistoryPeriod period, Duration rollingRange) =>
    switch (period.kind) {
      HistoryPeriodKind.rolling => 'rolling:${rollingRange.inMilliseconds}',
      HistoryPeriodKind.today => 'today:${period.start.millisecondsSinceEpoch}',
      HistoryPeriodKind.refreshCycle =>
        'refresh:${period.start.millisecondsSinceEpoch}:'
            '${period.end.millisecondsSinceEpoch}',
    };
