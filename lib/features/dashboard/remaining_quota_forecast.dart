/// A safe, short-horizon estimate for the live quota window.
///
/// This deliberately models only the currently observed consumption trend. It
/// is not a capacity promise: quota usage is bursty, and the server resets a
/// window discontinuously.
class RemainingQuotaObservation {
  const RemainingQuotaObservation({
    required this.timestamp,
    required this.remainingPercent,
    this.resetAt,
  });

  final DateTime timestamp;
  final double remainingPercent;
  final DateTime? resetAt;
}

class RemainingQuotaForecast {
  const RemainingQuotaForecast({
    required this.start,
    required this.end,
    required this.startPercent,
    required this.endPercent,
    required this.percentPointsPerHour,
    required this.observationSpan,
  });

  final DateTime start;
  final DateTime end;
  final double startPercent;
  final double endPercent;
  final double percentPointsPerHour;
  final Duration observationSpan;
}

const _forecastLookback = Duration(hours: 3);
const _forecastBucket = Duration(minutes: 5);
const _maximumContinuityGap = Duration(minutes: 15);
const _minimumObservationSpan = Duration(minutes: 20);
const _minimumDeclinePerHour = 0.1;

/// Estimates the remaining quota using a robust recent trend.
///
/// The estimate requires at least four continuous five-minute observations over
/// twenty minutes. It isolates the current reset cycle, discards older polling
/// gaps, uses the median of all pair slopes (Theil-Sen), then pulls that slope
/// toward zero for volatility and for an observation span under one hour. This
/// makes a short, half-day history useful without extrapolating a one-off
/// burst. The returned line starts after the last real observation and covers
/// only the future portion of the requested chart period.
RemainingQuotaForecast? forecastRemainingQuota(
  Iterable<RemainingQuotaObservation> source, {
  required DateTime asOf,
  required DateTime periodEnd,
}) {
  final observations =
      source.where((point) => !point.timestamp.isAfter(asOf)).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (observations.length < 4) return null;

  final cycle = _currentCycle(observations);
  final latest = cycle.last;
  final lookbackStart = latest.timestamp.subtract(_forecastLookback);
  final recent = cycle
      .where((point) => !point.timestamp.isBefore(lookbackStart))
      .toList();
  final bucketed = _latestContinuousRun(_lastObservationPerBucket(recent));
  if (bucketed.length < 4) return null;

  final observationSpan = bucketed.last.timestamp.difference(
    bucketed.first.timestamp,
  );
  if (observationSpan < _minimumObservationSpan) return null;

  final slopes = <double>[];
  for (var left = 0; left < bucketed.length - 1; left++) {
    for (var right = left + 1; right < bucketed.length; right++) {
      final elapsedHours =
          bucketed[right].timestamp
              .difference(bucketed[left].timestamp)
              .inMilliseconds /
          Duration.millisecondsPerHour;
      if (elapsedHours > 0) {
        slopes.add(
          (bucketed[right].remainingPercent - bucketed[left].remainingPercent) /
              elapsedHours,
        );
      }
    }
  }
  if (slopes.isEmpty) return null;

  final trend = _median(slopes);
  final volatility = _median(
    slopes.map((slope) => (slope - trend).abs()).toList(),
  );
  // A volatile decline is intentionally made less steep. If the noise is as
  // large as the signal, no prediction is better than a misleading one.
  final noiseAdjustedTrend = (trend + volatility * .75)
      .clamp(double.negativeInfinity, 0)
      .toDouble();
  final spanConfidence =
      (observationSpan.inMilliseconds / const Duration(hours: 1).inMilliseconds)
          .clamp(.35, 1.0)
          .toDouble();
  final conservativeTrend = noiseAdjustedTrend * spanConfidence;
  if (conservativeTrend >= -_minimumDeclinePerHour) return null;

  final forecastStart = latest.timestamp.isAfter(asOf)
      ? latest.timestamp
      : asOf;
  if (!periodEnd.isAfter(forecastStart)) return null;
  double estimateAt(DateTime timestamp) =>
      (latest.remainingPercent +
              conservativeTrend *
                  (timestamp.difference(latest.timestamp).inMilliseconds /
                      Duration.millisecondsPerHour))
          .clamp(0, 100)
          .toDouble();
  final startPercent = estimateAt(forecastStart);
  final endPercent = estimateAt(periodEnd);
  if ((startPercent - endPercent).abs() < .5) return null;

  return RemainingQuotaForecast(
    start: forecastStart,
    end: periodEnd,
    startPercent: startPercent,
    endPercent: endPercent,
    percentPointsPerHour: conservativeTrend,
    observationSpan: observationSpan,
  );
}

List<RemainingQuotaObservation> _currentCycle(
  List<RemainingQuotaObservation> observations,
) {
  var firstCurrentIndex = 0;
  for (var i = 1; i < observations.length; i++) {
    final previous = observations[i - 1];
    final current = observations[i];
    final remainingJumpedUp =
        current.remainingPercent - previous.remainingPercent >= 8;
    if (remainingJumpedUp) firstCurrentIndex = i;
  }
  return observations.sublist(firstCurrentIndex);
}

List<RemainingQuotaObservation> _lastObservationPerBucket(
  Iterable<RemainingQuotaObservation> observations,
) {
  final buckets = <int, RemainingQuotaObservation>{};
  for (final point in observations) {
    final bucket =
        point.timestamp.millisecondsSinceEpoch ~/
        _forecastBucket.inMilliseconds;
    buckets[bucket] = point;
  }
  final result = buckets.values.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return result;
}

List<RemainingQuotaObservation> _latestContinuousRun(
  List<RemainingQuotaObservation> observations,
) {
  var first = observations.length - 1;
  while (first > 0 &&
      observations[first].timestamp.difference(
            observations[first - 1].timestamp,
          ) <=
          _maximumContinuityGap) {
    first--;
  }
  return observations.sublist(first);
}

double _median(List<double> values) {
  values.sort();
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle]
      : (values[middle - 1] + values[middle]) / 2;
}
