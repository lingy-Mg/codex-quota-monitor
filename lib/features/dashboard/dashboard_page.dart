import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/monitor_controller.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../core/bounded_cache.dart';
import '../../core/history_consumption.dart';
import '../../core/models.dart';
import '../../database/app_database.dart';
import 'history_period.dart';
import 'remaining_quota_forecast.dart';
import 'quota_overview.dart';
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
  late final ValueNotifier<DateTime> _clock;
  Duration? _selectedRange;
  HistoryPeriodKind _periodKind = HistoryPeriodKind.rolling;
  @override
  void initState() {
    super.initState();
    _clock = ValueNotifier(widget.now?.call() ?? DateTime.now());
    if (widget.now == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _clock.value = DateTime.now();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.preview ?? ref.watch(dashboardProvider).value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final setting = ref.watch(settingsProvider).value;
    final range = _selectedRange ?? _savedHistoryRange(setting);
    final windows = state.usage?.rateLimit.windows ?? const <RateWindow>[];
    final short = windows.isEmpty ? null : windows.first;
    final now = widget.now?.call() ?? _clock.value;
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
                flex: 46,
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _clock,
                  builder: (context, clockNow, child) => QuotaOverview(
                    usage: state.usage,
                    now: widget.now?.call() ?? clockNow,
                    stale: state.health != MonitorHealth.live,
                    gap: gap,
                    onExpired: widget.preview == null
                        ? () => ref
                              .read(dashboardProvider.notifier)
                              .onCountdownEnded()
                        : () {},
                  ),
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                flex: 54,
                child: Row(
                  children: [
                    Expanded(
                      flex: 70,
                      child: _History(
                        range: range,
                        onRange: _selectRange,
                        periodKind: _periodKind,
                        onPeriodKind: (value) =>
                            setState(() => _periodKind = value),
                        stamp: state.lastSync,
                        asOf: now,
                        refreshWindow: short,
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
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: LayoutBuilder(
          builder: (context, viewport) {
            // Some Android desktop/emulator displays report only 640×360dp
            // while rendering at 1280×720 pixels. The full monitoring screen is
            // intentionally a fixed one-screen dashboard, so scale its proven
            // tablet grid instead of letting card contents overflow or scroll.
            final useCompactCanvas =
                viewport.maxWidth < 1000 || viewport.maxHeight < 700;
            if (!useCompactCanvas) return dashboard;
            final baselineHeight =
                1080 * viewport.maxHeight / viewport.maxWidth;
            return ColoredBox(
              color: AppColors.bg,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  // Match the baseline aspect ratio to the real viewport. This
                  // keeps the compact 16:9 canvas unchanged while allowing a
                  // 16:10 tablet to consume its extra vertical space.
                  child: SizedBox(
                    width: 1080,
                    height: baselineHeight,
                    child: dashboard,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _selectRange(Duration range) {
    setState(() {
      _selectedRange = range;
      _periodKind = HistoryPeriodKind.rolling;
    });
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    unawaited(
      ref
          .read(settingsProvider.notifier)
          .saveSettings(
            settings.copyWith(historyRangeMinutes: range.inMinutes),
          ),
    );
  }
}

Duration _savedHistoryRange(AppSettings? settings) {
  final saved = Duration(
    minutes:
        settings?.historyRangeMinutes ?? const Duration(hours: 24).inMinutes,
  );
  return _ranges.any((option) => option.$2 == saved)
      ? saved
      : const Duration(hours: 24);
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
  const _CardTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: AppColors.text,
      fontSize: 16,
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
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderStatus(
                      icon: Icons.circle,
                      iconColor: health == MonitorHealth.live
                          ? AppColors.green
                          : AppColors.warning,
                      label:
                          '网络 ${health == MonitorHealth.live ? '在线' : label}',
                    ),
                    _HeaderStatus(
                      icon: Icons.wifi_outlined,
                      label: 'Wi-Fi ${state.device?.wifiIp ?? '--'}',
                    ),
                    _HeaderStatus(
                      icon: Icons.refresh_rounded,
                      label: '自动刷新 ${refresh}s',
                    ),
                    _HeaderStatus(
                      icon: Icons.bolt_outlined,
                      label: state.device?.charging == true ? '已供电' : '电池供电',
                    ),
                    _HeaderStatus(
                      icon: Icons.memory_outlined,
                      label: state.device == null
                          ? '内存 --'
                          : '内存 ${state.device!.memoryMb.toStringAsFixed(1)} MB',
                    ),
                    const _HeaderStatus(
                      icon: Icons.dark_mode_outlined,
                      label: '深色模式',
                    ),
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
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        tooltip: '设置',
                      ),
                    ),
                  ],
                ),
              ),
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

class _History extends ConsumerStatefulWidget {
  const _History({
    required this.range,
    required this.onRange,
    required this.periodKind,
    required this.onPeriodKind,
    required this.asOf,
    this.refreshWindow,
    this.stamp,
  });
  final Duration range;
  final ValueChanged<Duration> onRange;
  final HistoryPeriodKind periodKind;
  final ValueChanged<HistoryPeriodKind> onPeriodKind;
  final DateTime asOf;
  final RateWindow? refreshWindow;
  final DateTime? stamp;

  @override
  ConsumerState<_History> createState() => _HistoryState();
}

enum _HistoryChartMode { remaining, consumption }

class _HistoryState extends ConsumerState<_History> {
  _HistoryChartMode _chartMode = _HistoryChartMode.remaining;
  final BoundedCache<String, List<QuotaSnapshot>> _cache = BoundedCache(
    maxEntries: 8,
  );
  List<QuotaSnapshot> _visibleRows = const [];
  _HistoryTouchPoint? _selectedPoint;
  Timer? _panLoadDebounce;
  Duration _timelineOffset = Duration.zero;
  Duration _dragStartOffset = Duration.zero;
  double _dragDistance = 0;
  var _isDragging = false;
  var _hasLoaded = false;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _panLoadDebounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _History oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPeriod = _historyPeriodFor(oldWidget);
    final period = _historyPeriodFor(widget);
    final crossedFixedBoundary =
        period?.isFixed == true && oldPeriod?.start != period?.start;
    final selectionChanged =
        oldWidget.range != widget.range ||
        oldWidget.periodKind != widget.periodKind;
    if (selectionChanged ||
        oldWidget.stamp != widget.stamp ||
        crossedFixedBoundary) {
      if (selectionChanged || crossedFixedBoundary) {
        _timelineOffset = Duration.zero;
        _selectedPoint = null;
      }
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final range = widget.range;
    final periodKind = widget.periodKind;
    final timelineOffset = _timelineOffset;
    final period = _visibleHistoryPeriod;
    final requestId = ++_requestId;
    if (period == null) {
      if (mounted) {
        setState(() {
          _visibleRows = const [];
          _hasLoaded = true;
        });
      }
      return;
    }
    final cacheKey = _timelineCacheKey(period, range, timelineOffset);
    final cached = _cache.get(cacheKey);
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
      if (!mounted ||
          requestId != _requestId ||
          widget.range != range ||
          widget.periodKind != periodKind ||
          _timelineOffset != timelineOffset) {
        return;
      }
      setState(() {
        _cache.put(cacheKey, rows);
        _visibleRows = rows;
        _hasLoaded = true;
      });
    } catch (_) {
      // Keep the last successfully rendered chart in place if a local read
      // fails. The dashboard's next sync/range change will retry it.
    }
  }

  HistoryPeriod? get _visibleHistoryPeriod {
    final period = _historyPeriodFor(widget);
    return period == null ? null : shiftHistoryPeriod(period, _timelineOffset);
  }

  void _startTimelineDrag(DragStartDetails details) {
    _panLoadDebounce?.cancel();
    _dragStartOffset = _timelineOffset;
    _dragDistance = 0;
    setState(() {
      _isDragging = true;
      _selectedPoint = null;
    });
  }

  void _updateTimelineDrag(DragUpdateDetails details, double width) {
    _dragDistance += details.delta.dx;
    final period = _historyPeriodFor(widget);
    if (period == null) return;
    final hours = timelineHourShiftForDrag(
      dragDistance: _dragDistance,
      viewportWidth: width,
      visibleDuration: period.end.difference(period.start),
    );
    final next = _dragStartOffset + Duration(hours: hours);
    if (next == _timelineOffset) return;
    setState(() => _timelineOffset = next);
    _panLoadDebounce?.cancel();
    _panLoadDebounce = Timer(
      const Duration(milliseconds: 120),
      () => unawaited(_load()),
    );
  }

  void _endTimelineDrag() {
    _panLoadDebounce?.cancel();
    if (_isDragging) setState(() => _isDragging = false);
    unawaited(_load());
  }

  void _returnToCurrentPeriod() {
    _panLoadDebounce?.cancel();
    setState(() {
      _timelineOffset = Duration.zero;
      _selectedPoint = null;
      _isDragging = false;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext c) {
    final period = _visibleHistoryPeriod;
    final consumptionUnit = historyConsumptionUnitFor(
      period?.end.difference(period.start) ?? widget.range,
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CardTitle('额度历史'),
              const Spacer(),
              if (_timelineOffset != Duration.zero)
                _RangeTab(
                  key: const ValueKey('history-timeline-now'),
                  label: '回到现在',
                  selected: false,
                  onTap: _returnToCurrentPeriod,
                ),
              const _HistoryGroupLabel('滚动窗口'),
              for (final option in _ranges)
                _RangeTab(
                  label: option.$1,
                  selected:
                      widget.periodKind == HistoryPeriodKind.rolling &&
                      widget.range == option.$2,
                  onTap: () => widget.onRange(option.$2),
                ),
              const _HistoryGroupDivider(),
              const _HistoryGroupLabel('独立周期'),
              _RangeTab(
                label: '今天',
                selected: widget.periodKind == HistoryPeriodKind.today,
                onTap: () => widget.onPeriodKind(HistoryPeriodKind.today),
              ),
              _RangeTab(
                label: '刷新周期内',
                selected: widget.periodKind == HistoryPeriodKind.refreshCycle,
                onTap: () =>
                    widget.onPeriodKind(HistoryPeriodKind.refreshCycle),
              ),
            ],
          ),
          Row(
            children: [
              _RangeTab(
                key: const ValueKey('history-mode-remaining'),
                label: '剩余额度',
                selected: _chartMode == _HistoryChartMode.remaining,
                onTap: () => setState(() {
                  _chartMode = _HistoryChartMode.remaining;
                  _selectedPoint = null;
                }),
              ),
              _RangeTab(
                key: const ValueKey('history-mode-consumption'),
                label: '额度消耗',
                selected: _chartMode == _HistoryChartMode.consumption,
                onTap: () => setState(() {
                  _chartMode = _HistoryChartMode.consumption;
                  _selectedPoint = null;
                }),
              ),
              if (_chartMode == _HistoryChartMode.consumption) ...[
                const SizedBox(width: 8),
                Text(
                  '每根柱为${historyConsumptionUnitLabel(consumptionUnit)}累计消耗',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Expanded(
            child: Builder(
              builder: (context) {
                if (period == null) {
                  return const Center(
                    child: Text(
                      '暂无 GPT 刷新周期信息',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  );
                }
                final chartDuration = period.end.difference(period.start);
                final remainingRows = sample(
                  _visibleRows
                      .where((row) => row.remainingPercent != null)
                      .toList(),
                  chartDuration,
                );
                final consumptionRows = historyConsumptionBuckets(
                  [
                    for (final row in _visibleRows)
                      (
                        timestamp: row.timestamp,
                        usedPercent: row.usedPercent,
                        resetAt: row.resetAt,
                        windowDurationSeconds: row.windowDurationSeconds,
                      ),
                  ],
                  start: period.start,
                  end: period.observedEnd(widget.asOf),
                  unit: consumptionUnit,
                );
                final isConsumption =
                    _chartMode == _HistoryChartMode.consumption;
                final axisMax = isConsumption
                    ? historyConsumptionAxisMax(
                        consumptionRows.map((row) => row.consumedPercent),
                      )
                    : 100.0;
                final minX = period.start.millisecondsSinceEpoch.toDouble();
                final maxX = period.end.millisecondsSinceEpoch.toDouble();
                final axisInterval = _historyAxisInterval(chartDuration);
                final forecastEnabled =
                    !isConsumption &&
                    widget.periodKind == HistoryPeriodKind.refreshCycle;
                final forecast = forecastEnabled
                    ? forecastRemainingQuota(
                        remainingRows
                            .map(
                              (row) => RemainingQuotaObservation(
                                timestamp: row.timestamp.toLocal(),
                                remainingPercent: row.remainingPercent!,
                              ),
                            )
                            .toList(),
                        asOf: widget.asOf,
                        periodEnd: period.end,
                      )
                    : null;
                return LayoutBuilder(
                  builder: (context, constraints) => MouseRegion(
                    cursor: _isDragging
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                    child: GestureDetector(
                      key: const ValueKey('history-timeline-pan'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _startTimelineDrag,
                      onHorizontalDragUpdate: (details) =>
                          _updateTimelineDrag(details, constraints.maxWidth),
                      onHorizontalDragEnd: (_) => _endTimelineDrag(),
                      onHorizontalDragCancel: _endTimelineDrag,
                      child: Stack(
                        children: [
                          if (isConsumption)
                            _consumptionBarChart(
                              period: period,
                              rows: consumptionRows,
                              unit: consumptionUnit,
                              axisMax: axisMax,
                              width: constraints.maxWidth,
                              onSelected: (point) =>
                                  setState(() => _selectedPoint = point),
                            )
                          else
                            LineChart(
                              LineChartData(
                                // fl_chart does not clip a curved path by default.  With
                                // the first/last data point on the chart edge, this could
                                // paint the path into both neighbouring cards.
                                clipData: const FlClipData.all(),
                                minX: minX,
                                maxX: maxX == minX ? minX + 1 : maxX,
                                minY: 0,
                                maxY: axisMax,
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: axisMax / 4,
                                  verticalInterval: axisInterval,
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
                                      reservedSize: isConsumption ? 36 : 26,
                                      interval: axisMax / 4,
                                      getTitlesWidget: (v, _) => Text(
                                        historyPercentLabel(v),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isConsumption
                                              ? AppColors.green
                                              : AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(),
                                  topTitles: const AxisTitles(),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: axisInterval,
                                      getTitlesWidget: (value, meta) =>
                                          _historyBottomTitle(
                                            value,
                                            meta,
                                            period: period,
                                            interval: axisInterval,
                                            timelineOffset: _timelineOffset,
                                          ),
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                extraLinesData: ExtraLinesData(
                                  verticalLines: [
                                    if (_selectedPoint case final selected?)
                                      VerticalLine(
                                        x: selected
                                            .timestamp
                                            .millisecondsSinceEpoch
                                            .toDouble(),
                                        color: selected.isForecast
                                            ? AppColors.purple
                                            : isConsumption
                                            ? AppColors.green
                                            : AppColors.cyan,
                                        strokeWidth: 1,
                                        dashArray: const [3, 3],
                                      ),
                                  ],
                                ),
                                lineBarsData: _historyLineBars(
                                  remainingRows,
                                  period: period,
                                  asOf: widget.asOf,
                                  range: chartDuration,
                                  forecast: forecast,
                                ),
                                lineTouchData: LineTouchData(
                                  touchSpotThreshold: 24,
                                  handleBuiltInTouches: false,
                                  touchCallback: _handleHistoryTouch,
                                  touchTooltipData: LineTouchTooltipData(
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
                                    maxContentWidth: 190,
                                    getTooltipItems: (spots) => spots.map((
                                      spot,
                                    ) {
                                      final point = _historyTouchPoint(spot);
                                      return LineTooltipItem(
                                        '${point.isForecast ? '预测' : '记录'}时间 '
                                        '${DateFormat('MM-dd HH:mm:ss').format(point.timestamp)}\n'
                                        '${point.valuesLabel}',
                                        TextStyle(
                                          color:
                                              spot.bar.color == AppColors.purple
                                              ? AppColors.purple
                                              : AppColors.text,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          if (isConsumption
                              ? consumptionRows.isEmpty
                              : remainingRows.isEmpty)
                            Center(
                              child: IgnorePointer(
                                child: _hasLoaded
                                    ? Text(
                                        isConsumption
                                            ? '此时间段暂无可计算的消耗 · 至少需要两次有效记录'
                                            : '此时间段暂无记录 · 可继续左右拖动',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                        ),
                                      )
                                    : const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                              ),
                            ),
                          if (isConsumption
                              ? consumptionRows.isNotEmpty
                              : remainingRows.isNotEmpty)
                            Positioned(
                              top: 2,
                              left: 34,
                              child: IgnorePointer(
                                child: _HistoryValueLegend(
                                  label: isConsumption
                                      ? historyConsumptionValueLabel(
                                          consumptionUnit,
                                          consumptionRows.last.consumedPercent,
                                        )
                                      : '剩余 ${historyPercentLabel(remainingRows.last.remainingPercent!)}',
                                  color: isConsumption
                                      ? AppColors.green
                                      : AppColors.cyan,
                                ),
                              ),
                            ),
                          if (forecast != null)
                            Positioned(
                              top: 2,
                              right: 4,
                              child: IgnorePointer(
                                child: _ForecastLegend(forecast: forecast),
                              ),
                            ),
                          if (_selectedPoint case final selected?)
                            Positioned(
                              top: 2,
                              left: 32,
                              child: _HistoryTouchLabel(point: selected),
                            ),
                        ],
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

  void _handleHistoryTouch(FlTouchEvent event, LineTouchResponse? response) {
    if (event is! FlTapUpEvent) return;
    final spots = response?.lineBarSpots;
    if (spots == null || spots.isEmpty) {
      setState(() => _selectedPoint = null);
      return;
    }
    final spot = spots.first;
    setState(() {
      _selectedPoint = _historyTouchPoint(spot);
    });
  }
}

class _RangeTab extends StatelessWidget {
  const _RangeTab({
    super.key,
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

class _HistoryGroupLabel extends StatelessWidget {
  const _HistoryGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpace.xs, right: 2),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.secondary, fontSize: 9),
    ),
  );
}

class _HistoryGroupDivider extends StatelessWidget {
  const _HistoryGroupDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: AppColors.divider,
  );
}

const _ranges = [
  ('1小时', Duration(hours: 1)),
  ('6小时', Duration(hours: 6)),
  ('12小时', Duration(hours: 12)),
  ('24小时', Duration(hours: 24)),
  ('7天', Duration(days: 7)),
];

HistoryPeriod? _historyPeriodFor(_History widget) =>
    switch (widget.periodKind) {
      HistoryPeriodKind.rolling => rollingHistoryPeriod(
        widget.range,
        widget.asOf,
      ),
      HistoryPeriodKind.today => todayHistoryPeriod(widget.asOf),
      HistoryPeriodKind.refreshCycle => refreshCycleHistoryPeriod(
        durationSeconds: widget.refreshWindow?.durationSeconds,
        resetAt: widget.refreshWindow?.resetAt,
      ),
    };

double _historyAxisInterval(Duration duration) {
  if (duration <= const Duration(hours: 1)) {
    return timelineMinimumStep.inMilliseconds.toDouble();
  }
  if (duration <= const Duration(hours: 6)) {
    return const Duration(hours: 1).inMilliseconds.toDouble();
  }
  if (duration <= const Duration(hours: 12)) {
    return const Duration(hours: 2).inMilliseconds.toDouble();
  }
  if (duration <= const Duration(days: 1)) {
    return const Duration(hours: 4).inMilliseconds.toDouble();
  }
  return const Duration(days: 1).inMilliseconds.toDouble();
}

String _timelineCacheKey(
  HistoryPeriod period,
  Duration rollingRange,
  Duration timelineOffset,
) =>
    '${historyCacheKey(period, rollingRange)}:timeline:${timelineOffset.inHours}';

Widget _historyBottomTitle(
  double value,
  TitleMeta meta, {
  required HistoryPeriod period,
  required double interval,
  Duration timelineOffset = Duration.zero,
}) {
  final nearStart = (value - meta.min).abs() < 1;
  final nearEnd = (value - meta.max).abs() < 1;
  if (!nearStart && !nearEnd) {
    final tooCloseToStart = value - meta.min < interval * .45;
    final tooCloseToEnd = meta.max - value < interval * .45;
    if (tooCloseToStart || tooCloseToEnd) return const SizedBox.shrink();
  }

  final time = DateTime.fromMillisecondsSinceEpoch(value.round());
  final duration = period.end.difference(period.start);
  final label = switch (period.kind) {
    HistoryPeriodKind.today =>
      timelineOffset == Duration.zero
          ? nearEnd
                ? '24:00'
                : DateFormat('HH:mm').format(time)
          : DateFormat('MM-dd\nHH:mm').format(time),
    HistoryPeriodKind.refreshCycle =>
      duration <= const Duration(hours: 12)
          ? DateFormat('HH:mm').format(time)
          : DateFormat('MM-dd\nHH:mm').format(time),
    HistoryPeriodKind.rolling =>
      duration <= const Duration(hours: 12)
          ? DateFormat('HH:mm').format(time)
          : duration <= const Duration(days: 1)
          ? DateFormat('MM-dd\nHH:mm').format(time)
          : DateFormat('MM-dd').format(time),
  };
  return SideTitleWidget(
    meta: meta,
    space: 5,
    fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 2),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted, fontSize: 8, height: 1.1),
    ),
  );
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
  RemainingQuotaForecast? forecast,
}) {
  final observedEnd = period.observedEnd(asOf);
  final visibleRows = rows
      .where(
        (row) =>
            !row.timestamp.isBefore(period.start) &&
            !row.timestamp.isAfter(observedEnd),
      )
      .toList();
  final remainingPoints = visibleRows
      .map(
        (row) => FlSpot(
          row.timestamp.millisecondsSinceEpoch.toDouble(),
          row.remainingPercent!,
        ),
      )
      .toList();
  if (remainingPoints.isEmpty) return const [];
  return [
    ..._historySeriesLines(
      remainingPoints,
      period: period,
      observedEnd: observedEnd,
      range: range,
      color: AppColors.cyan,
      fill: true,
    ),
    if (forecast != null) _forecastLine(forecast),
  ];
}

Widget _consumptionBarChart({
  required HistoryPeriod period,
  required List<HistoryConsumptionBucket> rows,
  required Duration unit,
  required double axisMax,
  required double width,
  required ValueChanged<_HistoryTouchPoint?> onSelected,
}) {
  final start = period.start.toLocal();
  final slots = <DateTime>[];
  final dayStart = DateTime(start.year, start.month, start.day);
  final unitMs = unit.inMilliseconds;
  var slot = dayStart.add(
    Duration(
      milliseconds:
          start.difference(dayStart).inMilliseconds ~/ unitMs * unitMs,
    ),
  );
  while (slot.isBefore(period.end)) {
    slots.add(slot);
    slot = slot.add(unit);
  }
  final values = <int, HistoryConsumptionBucket>{};
  for (final row in rows) {
    final index =
        row.timestamp.difference(slots.first).inMilliseconds ~/ unitMs;
    if (index >= 0 && index < slots.length) values[index] = row;
  }
  final barWidth = _consumptionBarWidth(width, slots.length);
  final labelStep = (slots.length / 4).ceil().clamp(1, 48);
  final duration = period.end.difference(period.start);
  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      minY: 0,
      maxY: axisMax,
      barGroups: [
        for (var index = 0; index < slots.length; index++)
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index] == null
                    ? 0
                    : values[index]!.consumedPercent.clamp(
                        axisMax * .012,
                        axisMax,
                      ),
                width: barWidth,
                color: values[index] == null
                    ? Colors.transparent
                    : AppColors.green,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
            ],
          ),
      ],
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: axisMax / 4,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: AppColors.divider, strokeWidth: .7),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: axisMax / 4,
            getTitlesWidget: (value, _) => Text(
              historyPercentLabel(value),
              style: const TextStyle(fontSize: 9, color: AppColors.green),
            ),
          ),
        ),
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: labelStep.toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 ||
                  index >= slots.length ||
                  index % labelStep != 0) {
                return const SizedBox.shrink();
              }
              final format = duration <= const Duration(hours: 12)
                  ? 'HH:mm'
                  : duration <= const Duration(days: 1)
                  ? 'MM-dd\nHH:mm'
                  : 'MM-dd';
              return SideTitleWidget(
                meta: meta,
                space: 5,
                fitInside: SideTitleFitInsideData.fromTitleMeta(
                  meta,
                  distanceFromEdge: 2,
                ),
                child: Text(
                  DateFormat(format).format(slots[index]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 8,
                    height: 1.1,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        handleBuiltInTouches: false,
        touchExtraThreshold: const EdgeInsets.symmetric(horizontal: 4),
        touchCallback: (event, response) {
          if (event is! FlTapUpEvent) return;
          final index = response?.spot?.touchedBarGroupIndex;
          final row = index == null ? null : values[index];
          onSelected(
            row == null
                ? null
                : _HistoryTouchPoint(
                    timestamp: row.timestamp,
                    value: row.consumedPercent,
                    isForecast: false,
                    mode: _HistoryChartMode.consumption,
                    consumptionUnit: unit,
                  ),
          );
        },
        touchTooltipData: BarTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          maxContentWidth: 190,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final row = values[groupIndex];
            if (row == null) return null;
            return BarTooltipItem(
              '记录时间 ${DateFormat('MM-dd HH:mm').format(row.timestamp)}\n'
              '${historyConsumptionValueLabel(unit, row.consumedPercent)}',
              const TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ),
    ),
  );
}

double _consumptionBarWidth(double chartWidth, int slotCount) {
  final space = (chartWidth - 50).clamp(1.0, double.infinity);
  final natural = space / slotCount * .62;
  return natural.clamp(slotCount <= 25 ? 7.0 : 2.0, 14.0);
}

List<LineChartBarData> _historySeriesLines(
  List<FlSpot> points, {
  required HistoryPeriod period,
  required DateTime observedEnd,
  required Duration range,
  required Color color,
  bool fill = false,
}) {
  if (points.isEmpty) return const [];

  final dashed = <LineChartBarData>[];
  final solid = <LineChartBarData>[];
  final start = FlSpot(
    period.start.millisecondsSinceEpoch.toDouble(),
    points.first.y,
  );
  if (start.x < points.first.x) {
    dashed.add(_dashedHistoryLine([start, points.first], color));
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
      solid.add(_solidHistoryLine(run, color, fill: fill));
    }
    dashed.add(_dashedHistoryLine([previous, current], color));
    run = [current];
  }
  if (run.length > 1) {
    solid.add(_solidHistoryLine(run, color, fill: fill));
  }

  final observed = FlSpot(
    observedEnd.millisecondsSinceEpoch.toDouble(),
    points.last.y,
  );
  if (points.last.x < observed.x) {
    dashed.add(_dashedHistoryLine([points.last, observed], color));
  }
  final end = FlSpot(period.end.millisecondsSinceEpoch.toDouble(), observed.y);
  if (observed.x < end.x) {
    dashed.add(_dashedHistoryLine([observed, end], color));
  }
  return [...dashed, ...solid];
}

Duration _historyGapThreshold(Duration range) {
  if (range.inDays >= 30) return const Duration(hours: 4);
  if (range.inDays >= 7) return const Duration(hours: 1);
  if (range.inHours >= 24) return const Duration(minutes: 10);
  if (range.inHours >= 6) return const Duration(minutes: 5);
  return const Duration(minutes: 2);
}

LineChartBarData _dashedHistoryLine(List<FlSpot> spots, Color color) =>
    LineChartBarData(
      spots: spots,
      color: color.withValues(alpha: .55),
      isCurved: false,
      barWidth: 1.5,
      dashArray: const [7, 5],
      dotData: const FlDotData(show: false),
    );

LineChartBarData _solidHistoryLine(
  List<FlSpot> spots,
  Color color, {
  required bool fill,
}) => LineChartBarData(
  spots: spots,
  color: color,
  isCurved: true,
  preventCurveOverShooting: true,
  preventCurveOvershootingThreshold: 0,
  barWidth: 2,
  dotData: const FlDotData(show: false),
  belowBarData: BarAreaData(show: fill, color: color.withValues(alpha: .07)),
);

LineChartBarData _forecastLine(RemainingQuotaForecast forecast) =>
    LineChartBarData(
      spots: [
        FlSpot(
          forecast.start.millisecondsSinceEpoch.toDouble(),
          forecast.startPercent,
        ),
        FlSpot(
          forecast.end.millisecondsSinceEpoch.toDouble(),
          forecast.endPercent,
        ),
      ],
      color: AppColors.purple,
      isCurved: false,
      barWidth: 2,
      dashArray: const [5, 4],
      dotData: const FlDotData(show: false),
    );

class _ForecastLegend extends StatelessWidget {
  const _ForecastLegend({required this.forecast});

  final RemainingQuotaForecast forecast;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.card.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 2, color: AppColors.purple),
          const SizedBox(width: 4),
          Text(
            '趋势预测 ${forecast.percentPointsPerHour.abs().toStringAsFixed(1)}%/小时',
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HistoryTouchPoint {
  const _HistoryTouchPoint({
    required this.timestamp,
    required this.value,
    required this.isForecast,
    required this.mode,
    this.consumptionUnit,
  });

  final DateTime timestamp;
  final double value;
  final bool isForecast;
  final _HistoryChartMode mode;
  final Duration? consumptionUnit;

  String get valuesLabel => mode == _HistoryChartMode.consumption
      ? historyConsumptionValueLabel(consumptionUnit!, value)
      : '剩余 ${historyPercentLabel(value)}';
}

_HistoryTouchPoint _historyTouchPoint(LineBarSpot spot) => _HistoryTouchPoint(
  timestamp: DateTime.fromMillisecondsSinceEpoch(spot.x.round()),
  value: spot.y,
  isForecast: spot.bar.color == AppColors.purple,
  mode: _HistoryChartMode.remaining,
);

class _HistoryValueLegend extends StatelessWidget {
  const _HistoryValueLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.card.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 7),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    ),
  );
}

class _HistoryTouchLabel extends StatelessWidget {
  const _HistoryTouchLabel({required this.point});

  final _HistoryTouchPoint point;

  @override
  Widget build(BuildContext context) {
    final color = point.isForecast
        ? AppColors.purple
        : point.mode == _HistoryChartMode.consumption
        ? AppColors.green
        : AppColors.cyan;
    return Semantics(
      label:
          '${point.isForecast ? '预测' : '记录'}时间 '
          '${DateFormat('yyyy-MM-dd HH:mm:ss').format(point.timestamp)}，'
          '${point.valuesLabel}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: .55)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Text(
            '${point.isForecast ? '预测' : '记录'} '
            '${DateFormat('MM-dd HH:mm:ss').format(point.timestamp)}  '
            '${point.valuesLabel}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

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
