import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/models.dart';

class QuotaOverview extends StatelessWidget {
  const QuotaOverview({
    super.key,
    required this.usage,
    required this.now,
    required this.stale,
    required this.gap,
    required this.onExpired,
  });

  final CodexUsageResponse? usage;
  final DateTime now;
  final bool stale;
  final double gap;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    final windows = usage?.rateLimit.windows ?? const <RateWindow>[];
    final window = windows.firstOrNull;
    final secondaryWindow = windows.length > 1 ? windows[1] : null;
    final remaining = window?.resetAt?.difference(now);
    if (remaining != null && remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onExpired());
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: _Panel(
            accent: AppColors.cyan,
            child: Column(
              children: [
                Expanded(
                  flex: 11,
                  child: _CurrentQuota(
                    window: window,
                    secondaryWindow: secondaryWindow,
                    now: now,
                    stale: stale,
                  ),
                ),
                const Divider(height: 18, color: AppColors.divider),
                Expanded(
                  flex: 9,
                  child: _Additional(
                    items: usage?.additional ?? const [],
                    now: now,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _ResetCards(usage: usage, now: now),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.accent, required this.child});
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent.withValues(alpha: .26)),
    ),
    child: child,
  );
}

class _CurrentQuota extends StatelessWidget {
  const _CurrentQuota({
    required this.window,
    required this.secondaryWindow,
    required this.now,
    required this.stale,
  });

  final RateWindow? window;
  final RateWindow? secondaryWindow;
  final DateTime now;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final remaining = window?.resetAt?.difference(now);
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 130;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  '当前额度',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 16),
                _BigText(
                  '${window?.remainingPercent?.round() ?? '--'}%',
                  size: compact ? 30 : 44,
                  color: _quotaColor(window?.remainingPercent),
                ),
                const SizedBox(width: 6),
                const Text(
                  '剩余',
                  style: TextStyle(color: AppColors.secondary, fontSize: 11),
                ),
                const Spacer(),
                const Text(
                  '剩余时间',
                  style: TextStyle(color: AppColors.secondary, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _BigText(
                    remaining == null ? '--' : durationClock(remaining),
                    size: compact ? 22 : 30,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
            _PairedTrack(window: window, now: now),
            if (secondaryWindow != null)
              _SecondaryQuotaLine(window: secondaryWindow!, now: now),
            Row(
              children: [
                Text(
                  '${quotaWindowLabel(window?.durationSeconds)}周期',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stale
                        ? '上次同步数据 · 等待更新'
                        : remaining != null && remaining <= Duration.zero
                        ? '周期已结束 · 等待刷新'
                        : '已使用 ${window?.usedPercent?.round() ?? '--'}%  ·  ${window?.resetAt == null ? '重置时间未知' : '${DateFormat('MM-dd HH:mm').format(window!.resetAt!.toLocal())} 重置'}',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: stale ? AppColors.warning : AppColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SecondaryQuotaLine extends StatelessWidget {
  const _SecondaryQuotaLine({required this.window, required this.now});

  final RateWindow window;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(
            '${quotaWindowLabel(window.durationSeconds)}额度',
            key: const ValueKey('quota-secondary-label'),
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '剩余 ${window.remainingPercent?.round() ?? '--'}%  ·  ${_additionalWindowLabel(window, now)}',
            key: const ValueKey('quota-secondary-summary'),
            style: const TextStyle(color: AppColors.secondary, fontSize: 9),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Semantics(
        key: const ValueKey('quota-secondary-track'),
        label:
            '${quotaWindowLabel(window.durationSeconds)}额度剩余 ${window.remainingPercent?.round() ?? '--'}%',
        child: _Track(
          value: window.remainingPercent,
          color: AppColors.green,
          height: 5,
          keyPrefix: 'secondary-quota-segment',
        ),
      ),
    ],
  );
}

class _BigText extends StatelessWidget {
  const _BigText(this.text, {required this.size, required this.color});
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: TextStyle(
        fontSize: size,
        height: 1.12,
        fontWeight: FontWeight.w800,
        fontFamily: AppText.mono,
        color: color,
        letterSpacing: -1,
      ),
    ),
  );
}

/// Two independently scaled values share a single track: quota above, time below.
class _PairedTrack extends StatelessWidget {
  const _PairedTrack({required this.window, required this.now});
  final RateWindow? window;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '上层剩余额度 ${window?.remainingPercent?.round() ?? '--'}%，下层剩余时间 ${window?.timeRemainingPercent(now)?.round() ?? '--'}%',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          _Track(
            value: window?.remainingPercent,
            height: 16,
            // The short window is the primary balance, so keep it as one
            // continuous bar. Longer windows retain the seven-part treatment.
            segments: window?.durationSeconds == 18000 ? 1 : 7,
            keyPrefix: 'quota-track-segment',
          ),
          const SizedBox(height: 2),
          _Track(
            value: window?.timeRemainingPercent(now),
            color: AppColors.green,
            height: 8,
            balanceSensitive: false,
            keyPrefix: 'time-track-segment',
          ),
        ],
      ),
    ),
  );
}

class _Track extends StatelessWidget {
  const _Track({
    required this.value,
    this.color,
    this.height = 5,
    this.segments = 1,
    this.keyPrefix = 'quota-track-segment',
    this.balanceSensitive = true,
  });
  final double? value;
  final Color? color;
  final double height;
  final int segments;
  final String keyPrefix;
  final bool balanceSensitive;

  @override
  Widget build(BuildContext context) {
    final normalized = (value ?? 0).clamp(0, 100).toDouble();
    return TweenAnimationBuilder<double>(
      // Starting at the current value avoids an empty flash on first load.
      // Rebuilds animate from the currently displayed value to the new quota.
      tween: Tween<double>(begin: normalized, end: normalized),
      duration: const Duration(milliseconds: 2400),
      curve: Curves.easeInOutCubic,
      builder: (context, animatedValue, _) => SizedBox(
        height: height,
        child: Row(
          children: [
            for (var index = 0; index < segments; index++) ...[
              if (index > 0) const SizedBox(width: 3),
              Expanded(
                child: _TrackSegment(
                  key: ValueKey('$keyPrefix-$segments-$index'),
                  value: ((animatedValue * segments / 100) - index)
                      .clamp(0, 1)
                      .toDouble(),
                  gradient: _trackGradient(
                    balanceSensitive && value != null ? animatedValue : null,
                    fallback: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackSegment extends StatelessWidget {
  const _TrackSegment({super.key, required this.value, required this.gradient});

  final double value;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: AppColors.track),
      FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        heightFactor: 1,
        child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
      ),
    ],
  );
}

Color _quotaColor(double? value) {
  final remaining = ((value ?? 0).clamp(0, 100)) / 100;
  const stops = <(double, Color)>[
    (0, AppColors.error),
    (.25, Color(0xffF07852)),
    (.5, AppColors.warning),
    (.75, Color(0xffA9CE68)),
    (1, AppColors.green),
  ];
  for (var i = 1; i < stops.length; i++) {
    final (start, startColor) = stops[i - 1];
    final (end, endColor) = stops[i];
    if (remaining <= end) {
      return Color.lerp(
        startColor,
        endColor,
        (remaining - start) / (end - start),
      )!;
    }
  }
  return AppColors.green;
}

Gradient _trackGradient(double? remaining, {Color? fallback}) {
  final color = remaining == null
      ? fallback ?? AppColors.green
      : _quotaColor(remaining);
  return LinearGradient(
    colors: [
      Color.lerp(color, Colors.black, .12)!,
      color,
      Color.lerp(color, Colors.white, .14)!,
    ],
  );
}

class _ResetCards extends StatelessWidget {
  const _ResetCards({required this.usage, required this.now});
  final CodexUsageResponse? usage;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cards = usage?.resetCards?.toList()
      ?..sort((a, b) {
        if (a.expiresAt == null) return b.expiresAt == null ? 0 : 1;
        if (b.expiresAt == null) return -1;
        return a.expiresAt!.compareTo(b.expiresAt!);
      });
    final credits = usage?.credits;
    return _Panel(
      accent: AppColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '余额',
                style: TextStyle(color: AppColors.secondary, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Tooltip(
                  message: credits?.unlimited == true
                      ? 'Unlimited'
                      : credits?.balance ?? '--',
                  child: Text(
                    credits?.unlimited == true
                        ? 'Unlimited'
                        : credits?.balance ?? '--',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '重置卡 ${usage?.resetCredits ?? '--'} 张',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cards == null || cards.isEmpty
                ? Center(
                    child: Text(
                      cards == null ? '到期明细暂不可用' : '暂无可用重置卡',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 14,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) {
                      final ticketWidth = (box.maxWidth - 16) / 3;
                      return Scrollbar(
                        child: ListView.separated(
                          key: const ValueKey('reset-ticket-list'),
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          itemCount: cards.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => SizedBox(
                            width: ticketWidth,
                            child: _ResetTicket(
                              card: cards[index],
                              index: index,
                              now: now,
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

class _ResetTicket extends StatelessWidget {
  const _ResetTicket({
    required this.card,
    required this.index,
    required this.now,
  });
  final ResetCredit card;
  final int index;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final remaining = card.expiresAt?.difference(now);
    final urgent = remaining != null && remaining <= const Duration(days: 3);
    final color = urgent ? AppColors.warning : AppColors.purple;
    final days =
        remaining == null || remaining <= Duration.zero || remaining.inDays == 0
        ? null
        : remaining.inDays.clamp(1, 99).toString().padLeft(2, '0');
    final status = remaining == null
        ? '到期未知'
        : remaining <= Duration.zero
        ? '已到期'
        : '今日到期';
    return Semantics(
      label: '重置卡 ${index + 1}，${card.expiryLabel(now)}',
      child: Container(
        key: ValueKey('reset-ticket-$index'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Column(
          children: [
            Text(
              '卡 ${(index + 1).toString().padLeft(2, '0')}',
              style: TextStyle(
                color: color.withValues(alpha: .7),
                fontSize: 10,
              ),
            ),
            Expanded(
              child: Center(
                child: days == null
                    ? FittedBox(
                        child: Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '剩余',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 10,
                            ),
                          ),
                          _BigText(days, size: 46, color: color),
                          Text(
                            '天',
                            style: TextStyle(color: color, fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
            if (card.supportedByPlan == false)
              const FittedBox(
                child: Text(
                  '当前套餐不支持',
                  style: TextStyle(color: AppColors.warning, fontSize: 9),
                ),
              ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                card.expiresAt == null
                    ? '日期未知'
                    : DateFormat(
                        'yyyy-MM-dd',
                      ).format(card.expiresAt!.toLocal()),
                style: const TextStyle(color: AppColors.secondary, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Additional extends StatelessWidget {
  const _Additional({required this.items, required this.now});
  final List<AdditionalLimit> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('暂无附加额度', style: TextStyle(color: AppColors.secondary)),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        // Two quota rows are always visible; further limits remain scrollable.
        final rowHeight = ((box.maxHeight - 8) / 2).clamp(
          36.0,
          double.infinity,
        );
        return ListView.separated(
          primary: false,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final windows = item.rateLimit.windows;
            final window = windows.firstOrNull;
            final name = item.displayName.toLowerCase() == 'gpt-reserve'
                ? 'GPT Reserve'
                : '附加额度 · ${item.displayName}';
            return SizedBox(
              height: rowHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${window?.remainingPercent?.round() ?? '--'}%',
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppText.mono,
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    key: ValueKey('additional-track-$index'),
                    container: true,
                    label:
                        '$name 剩余额度 ${window?.remainingPercent?.round() ?? '--'}%',
                    child: _Track(
                      value: window?.remainingPercent,
                      color: AppColors.cyan,
                      height: 5,
                      keyPrefix: 'additional-quota-segment-$index',
                    ),
                  ),
                  Text(
                    windows.isEmpty
                        ? '暂无额度数据'
                        : windows
                              .map(
                                (w) =>
                                    '${windowLabel(w.durationSeconds)}周期 · 剩余 ${w.remainingPercent?.round() ?? '--'}% · ${_additionalWindowLabel(w, now)}',
                              )
                              .join('    /    '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 9,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

String _additionalWindowLabel(RateWindow window, DateTime now) {
  final resetAt = window.resetAt?.toLocal();
  if (resetAt == null) return '重置时间未知';
  final remaining = resetAt.difference(now);
  final countdown = remaining <= Duration.zero
      ? '已重置'
      : remaining.inDays > 0
      ? '${remaining.inDays}天'
      : remaining.inHours > 0
      ? '${remaining.inHours}小时'
      : '${remaining.inMinutes.clamp(1, 59)}分钟';
  return '$countdown ${DateFormat('MM-dd HH:mm').format(resetAt)}';
}
