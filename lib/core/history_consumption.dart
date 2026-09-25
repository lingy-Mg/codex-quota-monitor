typedef HistoryUsageObservation = ({
  DateTime timestamp,
  double? usedPercent,
  DateTime? resetAt,
  int? windowDurationSeconds,
});

class HistoryConsumptionBucket {
  const HistoryConsumptionBucket(this.timestamp, this.consumedPercent);

  final DateTime timestamp;
  final double consumedPercent;
}

/// Every consumption point represents one local clock hour.
const historyConsumptionUnit = Duration(hours: 1);

/// Sum observed increases in used quota into fixed time buckets. Resets and
/// long gaps are excluded because their consumption cannot be located reliably.
List<HistoryConsumptionBucket> historyConsumptionBuckets(
  List<HistoryUsageObservation> rows, {
  required DateTime start,
  required DateTime end,
  required Duration unit,
}) {
  final bucketMs = unit.inMilliseconds;
  if (bucketMs <= 0 || rows.length < 2) return const [];
  const maxGap = Duration(minutes: 10);
  final totals = <int, double>{};
  for (var i = 1; i < rows.length; i++) {
    final previous = rows[i - 1];
    final current = rows[i];
    if (current.timestamp.isBefore(start) || !current.timestamp.isBefore(end)) {
      continue;
    }
    final elapsed = current.timestamp.difference(previous.timestamp);
    final before = previous.usedPercent;
    final after = current.usedPercent;
    if (elapsed <= Duration.zero ||
        elapsed > maxGap ||
        before == null ||
        after == null ||
        !before.isFinite ||
        !after.isFinite ||
        before < 0 ||
        after > 100 ||
        after < before ||
        previous.resetAt != current.resetAt ||
        previous.windowDurationSeconds != current.windowDurationSeconds) {
      continue;
    }
    final local = current.timestamp.toLocal();
    final dayStart = DateTime(local.year, local.month, local.day);
    final bucket =
        dayStart.millisecondsSinceEpoch +
        local.difference(dayStart).inMilliseconds ~/ bucketMs * bucketMs;
    totals.update(
      bucket,
      (value) => value + after - before,
      ifAbsent: () => after - before,
    );
  }
  final keys = totals.keys.toList()..sort();
  return [
    for (final key in keys)
      HistoryConsumptionBucket(
        DateTime.fromMillisecondsSinceEpoch(key).isBefore(start)
            ? start
            : DateTime.fromMillisecondsSinceEpoch(key),
        totals[key]!,
      ),
  ];
}

double historyConsumptionAxisMax(Iterable<double> values) {
  var highest = 0.0;
  for (final value in values) {
    if (value.isFinite && value > highest) highest = value;
  }
  for (final ceiling in const [
    0.5,
    1.0,
    2.0,
    5.0,
    10.0,
    20.0,
    25.0,
    40.0,
    50.0,
    80.0,
    100.0,
  ]) {
    if (highest * 1.1 <= ceiling) return ceiling;
  }
  return 100;
}

String historyPercentLabel(double value) {
  final text = value.toStringAsFixed(value.abs() < 1 ? 2 : 1);
  return '${text.replaceFirst(RegExp(r'\.?0+$'), '')}%';
}
