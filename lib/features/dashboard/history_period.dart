/// The fixed calendar window used by a history chart.
///
/// A 24-hour chart is a local calendar day. A seven-day chart follows the
/// server-provided weekly quota cycle when its reset time is available. Other
/// options intentionally stay rolling windows ending at [now].
class HistoryPeriod {
  const HistoryPeriod({
    required this.start,
    required this.end,
    required this.isCalendarBounded,
  });

  final DateTime start;
  final DateTime end;
  final bool isCalendarBounded;

  /// The part of this period for which a real observation could exist.
  DateTime observedEnd(DateTime now) => now.isBefore(end) ? now : end;
}

HistoryPeriod historyPeriodFor(
  Duration range,
  DateTime now, {
  DateTime? weeklyResetAt,
}) {
  if (range == const Duration(hours: 24)) {
    final start = DateTime(now.year, now.month, now.day);
    return HistoryPeriod(
      start: start,
      end: start.add(const Duration(days: 1)),
      isCalendarBounded: true,
    );
  }
  if (range == const Duration(days: 7)) {
    final resetAt = weeklyResetAt?.toLocal();
    if (resetAt != null) {
      return HistoryPeriod(
        start: resetAt.subtract(const Duration(days: 7)),
        end: resetAt,
        isCalendarBounded: true,
      );
    }
  }
  return HistoryPeriod(
    start: now.subtract(range),
    end: now,
    isCalendarBounded: false,
  );
}
