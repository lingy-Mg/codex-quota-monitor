import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/monitor_controller.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../database/app_database.dart';
import 'history_period.dart';
import '../settings/settings_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key, this.preview, this.now});
  final DashboardState? preview;

  /// A frozen clock lets visual previews remain stable; normal monitoring uses
  /// the device clock and continues rebuilding once per second.
  final DateTime Function()? now;
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Timer? _ticker;
  Duration _range = const Duration(hours: 24);
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.preview ?? ref.watch(dashboardProvider).value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final setting = ref.watch(settingsProvider).value;
    final windows = state.usage?.rateLimit.windows ?? const <RateWindow>[];
    final short = windows.isEmpty ? null : windows.first;
    final now = widget.now?.call() ?? DateTime.now();
    final dashboard = LayoutBuilder(
      builder: (context, box) {
        final gap = box.maxWidth < 1400 ? AppSpace.sm : AppSpace.md;
        return Padding(
          padding: EdgeInsets.all(gap),
          child: Column(
            children: [
              _Header(
                state: state,
                refresh: setting?.refreshSeconds ?? 30,
                onSettings: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
              SizedBox(height: gap),
              Expanded(
                flex: 40,
                child: Row(
                  children: [
                    Expanded(
                      flex: 49,
                      child: _Hero(
                        window: short,
                        now: now,
                        onExpired: widget.preview == null
                            ? () => ref
                                  .read(dashboardProvider.notifier)
                                  .onCountdownEnded()
                            : () {},
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(flex: 16, child: _Credits(usage: state.usage)),
                    if (state.usage?.additional.isNotEmpty == true) ...[
                      SizedBox(width: gap),
                      Expanded(
                        flex: 18,
                        child: _Additional(item: state.usage!.additional.first),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                flex: 60,
                child: Row(
                  children: [
                    Expanded(
                      flex: 70,
                      child: _History(
                        range: _range,
                        onRange: (v) => setState(() => _range = v),
                        stamp: state.lastSync,
                        asOf: now,
                        weeklyResetAt: _weeklyResetAt(windows),
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(flex: 30, child: _Events(events: state.events)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) {
          // Some Android desktop/emulator displays report only 640×360dp
          // while rendering at 1280×720 pixels. The full monitoring screen is
          // intentionally a fixed one-screen dashboard, so scale its proven
          // tablet grid instead of letting card contents overflow or scroll.
          final useCompactCanvas =
              viewport.maxWidth < 1000 || viewport.maxHeight < 700;
          if (!useCompactCanvas) return dashboard;
          return ColoredBox(
            color: AppColors.bg,
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                // A 16:9 baseline fills compact landscape displays while
                // preserving the dashboard's grid proportions and readable
                // status text at 720p.
                child: SizedBox(width: 1080, height: 608, child: dashboard),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext c) => Container(
    padding: EdgeInsets.all(
      MediaQuery.sizeOf(c).height < 700 ? AppSpace.md : AppSpace.lg,
    ),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppSpace.radius),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text, {this.subtle = false});
  final String text;
  final bool subtle;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: subtle ? AppColors.secondary : AppColors.text,
      fontSize: subtle ? 14 : 16,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.refresh,
    required this.onSettings,
  });
  final DashboardState state;
  final int refresh;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext c) {
    final health = state.health;
    final color = health == MonitorHealth.live
        ? AppColors.green
        : health == MonitorHealth.auth
        ? AppColors.error
        : health == MonitorHealth.offline
        ? AppColors.warning
        : AppColors.cyan;
    final label = health == MonitorHealth.live
        ? 'LIVE'
        : health == MonitorHealth.auth
        ? 'AUTH'
        : health == MonitorHealth.offline
        ? 'OFFLINE'
        : 'SYNC';
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const Text(
            'Codex 额度监控',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              border: Border.all(color: color.withValues(alpha: .8)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: color, size: 6),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _HeaderStatus(
            icon: Icons.circle,
            iconColor: health == MonitorHealth.live
                ? AppColors.green
                : AppColors.warning,
            label: '网络 ${health == MonitorHealth.live ? '在线' : label}',
          ),
          _HeaderStatus(icon: Icons.refresh_rounded, label: '自动刷新 ${refresh}s'),
          _HeaderStatus(
            icon: Icons.bolt_outlined,
            label: state.device?.charging == true ? '已供电' : '电池供电',
          ),
          const _HeaderStatus(icon: Icons.dark_mode_outlined, label: '深色模式'),
          _HeaderStatus(
            icon: Icons.schedule_outlined,
            label:
                '最后同步 ${state.lastSync == null ? '--' : DateFormat('HH:mm:ss').format(state.lastSync!)}',
          ),
          const SizedBox(width: AppSpace.xs),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceHover.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined, size: 21),
              color: AppColors.text,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              tooltip: '设置',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.muted,
  });
  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpace.md),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: icon == Icons.circle ? 5 : 13, color: iconColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.window,
    required this.now,
    required this.onExpired,
  });
  final RateWindow? window;
  final DateTime now;
  final VoidCallback onExpired;
  @override
  Widget build(BuildContext c) {
    final compact = MediaQuery.sizeOf(c).height < 700;
    final resetDuration = window?.resetAt?.toLocal().difference(now);
    if (resetDuration?.isNegative == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onExpired());
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('当前额度', subtle: true),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '剩余 ${window?.remainingPercent?.round() ?? '--'}%',
                  style: TextStyle(
                    fontSize: compact ? 28 : 36,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                SizedBox(height: compact ? AppSpace.sm : AppSpace.md),
                _QuotaProgress(
                  label: '剩余资源',
                  value: window?.remainingPercent,
                  detail: '已使用 ${window?.usedPercent?.round() ?? '--'}%',
                  color: AppColors.cyan,
                ),
                SizedBox(height: compact ? AppSpace.xs : AppSpace.sm),
                _QuotaProgress(
                  label: '剩余时间',
                  value: window?.timeRemainingPercent(now),
                  detail: window?.resetAt == null
                      ? '重置 --'
                      : durationClock(resetDuration!),
                  color: AppColors.green,
                ),
              ],
            ),
          ),
          const Divider(height: AppSpace.lg, color: AppColors.divider),
          const Row(
            children: [
              Icon(Icons.circle, size: 6, color: AppColors.green),
              SizedBox(width: 6),
              Text(
                '实时更新 · 当前配额正常',
                style: TextStyle(color: AppColors.green, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotaProgress extends StatelessWidget {
  const _QuotaProgress({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });
  final String label;
  final double? value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext c) {
    final compact = MediaQuery.sizeOf(c).height < 700;
    final percent = value?.clamp(0, 100).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: compact ? 10 : 11,
              ),
            ),
            const Spacer(),
            Text(
              percent == null ? '--' : '${percent.round()}%',
              style: TextStyle(
                color: color,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
                fontFamily: AppText.mono,
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              detail,
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: compact ? 10 : 11,
                fontFamily: AppText.mono,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xxs),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: percent == null ? 0 : percent / 100,
            minHeight: compact ? 7 : 9,
            backgroundColor: AppColors.track,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _Credits extends StatelessWidget {
  const _Credits({this.usage});
  final CodexUsageResponse? usage;
  @override
  Widget build(BuildContext c) {
    final x = usage?.credits;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Credits'),
          const Spacer(),
          const Text('余额', style: TextStyle(color: AppColors.muted)),
          Text(
            x?.unlimited == true ? 'Unlimited' : x?.balance ?? '--',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            usage?.resetCredits == null
                ? 'Reset Credits --'
                : 'Reset Credits ×${usage!.resetCredits}',
            style: const TextStyle(color: AppColors.purple, fontSize: 12),
          ),
          Text(
            x?.hasCredits == true || x?.unlimited == true ? '状态 可用' : '状态 --',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Additional extends StatelessWidget {
  const _Additional({required this.item});
  final AdditionalLimit item;
  @override
  Widget build(BuildContext c) {
    final wins = item.rateLimit.windows;
    final w = wins.isEmpty ? null : wins.first;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('附加额度', subtle: true),
          const SizedBox(height: AppSpace.xxs),
          Text(
            item.displayName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            '剩余 ${w?.remainingPercent?.round() ?? '--'}%',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          Text(
            '已使用 ${w?.usedPercent?.round() ?? '--'}%',
            style: const TextStyle(color: AppColors.muted),
          ),
          const Spacer(),
          Text(
            wins
                .map(
                  (x) =>
                      '${windowLabel(x.durationSeconds)} ${x.remainingPercent?.round() ?? '--'}%',
                )
                .join(' · '),
            style: const TextStyle(
              color: AppColors.cyan,
              fontSize: 10,
              fontFamily: AppText.mono,
            ),
          ),
        ],
      ),
    );
  }
}

class _History extends ConsumerStatefulWidget {
  const _History({
    required this.range,
    required this.onRange,
    required this.asOf,
    this.weeklyResetAt,
    this.stamp,
  });
  final Duration range;
  final ValueChanged<Duration> onRange;
  final DateTime asOf;
  final DateTime? weeklyResetAt;
  final DateTime? stamp;

  @override
  ConsumerState<_History> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<_History> {
  final Map<Duration, List<QuotaSnapshot>> _cache = {};
  List<QuotaSnapshot> _visibleRows = const [];
  var _hasLoaded = false;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _History oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPeriod = historyPeriodFor(
      oldWidget.range,
      oldWidget.asOf,
      weeklyResetAt: oldWidget.weeklyResetAt,
    );
    final period = historyPeriodFor(
      widget.range,
      widget.asOf,
      weeklyResetAt: widget.weeklyResetAt,
    );
    final crossedCalendarBoundary =
        period.isCalendarBounded && oldPeriod.start != period.start;
    if (oldWidget.range != widget.range ||
        oldWidget.stamp != widget.stamp ||
        crossedCalendarBoundary) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final range = widget.range;
    final period = historyPeriodFor(
      range,
      widget.asOf,
      weeklyResetAt: widget.weeklyResetAt,
    );
    final requestId = ++_requestId;
    final cached = _cache[range];
    if (cached != null && !identical(cached, _visibleRows)) {
      setState(() {
        _visibleRows = cached;
        _hasLoaded = true;
      });
    }

    try {
      final rows = await ref
          .read(databaseProvider)
          .snapshotsBetween(period.start, period.observedEnd(widget.asOf));
      if (!mounted || requestId != _requestId || widget.range != range) return;
      setState(() {
        _cache[range] = rows;
        _visibleRows = rows;
        _hasLoaded = true;
      });
    } catch (_) {
      // Keep the last successfully rendered chart in place if a local read
      // fails. The dashboard's next sync/range change will retry it.
    }
  }

  @override
  Widget build(BuildContext c) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CardTitle('额度剩余历史'),
              const Spacer(),
              for (final option in _ranges)
                _RangeTab(
                  label: option.$1,
                  selected: widget.range == option.$2,
                  onTap: () => widget.onRange(option.$2),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Expanded(
            child: Builder(
              builder: (context) {
                final rows = sample(
                  _visibleRows
                      .where((row) => row.remainingPercent != null)
                      .toList(),
                  widget.range,
                );
                if (rows.isEmpty) {
                  return Center(
                    child: _hasLoaded
                        ? const Text(
                            '暂无已记录的额度数据',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          )
                        : const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  );
                }
                final period = historyPeriodFor(
                  widget.range,
                  widget.asOf,
                  weeklyResetAt: widget.weeklyResetAt,
                );
                final minX = period.start.millisecondsSinceEpoch.toDouble();
                final maxX = period.end.millisecondsSinceEpoch.toDouble();
                final lineBars = _historyLineBars(
                  rows,
                  period: period,
                  asOf: widget.asOf,
                  range: widget.range,
                );
                return LineChart(
                  LineChartData(
                    // fl_chart does not clip a curved path by default.  With
                    // the first/last data point on the chart edge, this could
                    // paint the path into both neighbouring cards.
                    clipData: const FlClipData.all(),
                    minX: minX,
                    maxX: maxX == minX ? minX + 1 : maxX,
                    minY: 0,
                    maxY: 100,
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 25,
                      verticalInterval: ((maxX - minX).abs() / 8).clamp(
                        1,
                        double.infinity,
                      ),
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AppColors.divider,
                        strokeWidth: .7,
                      ),
                      getDrawingVerticalLine: (_) => const FlLine(
                        color: AppColors.divider,
                        strokeWidth: .35,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: 25,
                          getTitlesWidget: (v, _) => Text(
                            '${v.round()}%',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: const AxisTitles(),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: lineBars,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots
                            .map(
                              (spot) => LineTooltipItem(
                                '剩余 ${spot.y.round()}%',
                                const TextStyle(color: AppColors.text),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeTab extends StatelessWidget {
  const _RangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpace.xxs),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyan.withValues(alpha: .10) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.cyan : AppColors.muted,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

const _ranges = [
  ('1小时', Duration(hours: 1)),
  ('6小时', Duration(hours: 6)),
  ('24小时', Duration(hours: 24)),
  ('7天', Duration(days: 7)),
  ('30天', Duration(days: 30)),
];

/// Usage responses can carry several rate-limit windows. Only a window whose
/// declared duration is approximately one week may anchor the 7-day chart.
DateTime? _weeklyResetAt(List<RateWindow> windows) {
  const minWeeklySeconds = 6 * 24 * 60 * 60;
  const maxWeeklySeconds = 8 * 24 * 60 * 60;
  for (final window in windows) {
    final duration = window.durationSeconds;
    if (duration != null &&
        duration >= minWeeklySeconds &&
        duration <= maxWeeklySeconds &&
        window.resetAt != null) {
      return window.resetAt;
    }
  }
  return null;
}

List<QuotaSnapshot> sample(List<QuotaSnapshot> rows, Duration range) {
  final max = range.inDays >= 30
      ? 360
      : range.inDays >= 7
      ? 336
      : range.inHours >= 24
      ? 288
      : range.inHours >= 6
      ? 180
      : 120;
  if (rows.length <= max) return rows;
  final step = (rows.length / max).ceil();
  return [for (var i = 0; i < rows.length; i += step) rows[i]];
}

/// A solid line means every neighbouring displayed sample was collected within
/// the normal polling allowance. Dashed links deliberately make offline gaps,
/// a newly-started chart, and the not-yet-elapsed calendar time visible rather
/// than pretending they are measured values.
List<LineChartBarData> _historyLineBars(
  List<QuotaSnapshot> rows, {
  required HistoryPeriod period,
  required DateTime asOf,
  required Duration range,
}) {
  final observedEnd = period.observedEnd(asOf);
  final points = rows
      .where(
        (row) =>
            !row.timestamp.isBefore(period.start) &&
            !row.timestamp.isAfter(observedEnd),
      )
      .map(
        (row) => FlSpot(
          row.timestamp.millisecondsSinceEpoch.toDouble(),
          row.remainingPercent!,
        ),
      )
      .toList();
  if (points.isEmpty) return const [];

  final dashed = <LineChartBarData>[];
  final solid = <LineChartBarData>[];
  final start = FlSpot(
    period.start.millisecondsSinceEpoch.toDouble(),
    points.first.y,
  );
  if (start.x < points.first.x) {
    dashed.add(_dashedHistoryLine([start, points.first]));
  }

  final maxGap = _historyGapThreshold(range);
  var run = <FlSpot>[points.first];
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final current = points[i];
    if (current.x - previous.x <= maxGap.inMilliseconds) {
      run.add(current);
      continue;
    }
    if (run.length > 1) {
      solid.add(_solidHistoryLine(run));
    }
    dashed.add(_dashedHistoryLine([previous, current]));
    run = [current];
  }
  if (run.length > 1) solid.add(_solidHistoryLine(run));

  final observed = FlSpot(
    observedEnd.millisecondsSinceEpoch.toDouble(),
    points.last.y,
  );
  if (points.last.x < observed.x) {
    dashed.add(_dashedHistoryLine([points.last, observed]));
  }
  final end = FlSpot(period.end.millisecondsSinceEpoch.toDouble(), observed.y);
  if (observed.x < end.x) dashed.add(_dashedHistoryLine([observed, end]));
  return [...dashed, ...solid];
}

Duration _historyGapThreshold(Duration range) {
  if (range.inDays >= 30) return const Duration(hours: 4);
  if (range.inDays >= 7) return const Duration(hours: 1);
  if (range.inHours >= 24) return const Duration(minutes: 10);
  if (range.inHours >= 6) return const Duration(minutes: 5);
  return const Duration(minutes: 2);
}

LineChartBarData _dashedHistoryLine(List<FlSpot> spots) => LineChartBarData(
  spots: spots,
  color: AppColors.muted.withValues(alpha: .8),
  isCurved: false,
  barWidth: 1.5,
  dashArray: const [7, 5],
  dotData: const FlDotData(show: false),
);

LineChartBarData _solidHistoryLine(List<FlSpot> spots) => LineChartBarData(
  spots: spots,
  color: AppColors.cyan,
  isCurved: true,
  preventCurveOverShooting: true,
  preventCurveOvershootingThreshold: 0,
  barWidth: 2,
  dotData: const FlDotData(show: false),
  belowBarData: BarAreaData(
    show: true,
    color: AppColors.cyan.withValues(alpha: .07),
  ),
);

class _Events extends StatelessWidget {
  const _Events({required this.events});
  final List<ActivityEvent> events;
  @override
  Widget build(BuildContext c) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardTitle('活动日志'),
        const SizedBox(height: AppSpace.xs),
        Expanded(
          child: events.isEmpty
              ? const Center(
                  child: Text(
                    '暂无额度变化记录',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  itemCount: events.length,
                  itemBuilder: (c, i) {
                    final e = events[i];
                    return Row(
                      children: [
                        Icon(
                          e.type == 'reset'
                              ? Icons.restart_alt
                              : Icons.trending_down,
                          size: 14,
                          color: e.type == 'reset'
                              ? AppColors.purple
                              : AppColors.cyan,
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Expanded(
                          child: Text(
                            e.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm:ss').format(e.timestamp.toLocal()),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.muted,
                            fontFamily: AppText.mono,
                          ),
                        ),
                      ],
                    );
                  },
                  separatorBuilder: (_, index) => const Divider(
                    height: AppSpace.md,
                    color: AppColors.divider,
                  ),
                ),
        ),
      ],
    ),
  );
}
