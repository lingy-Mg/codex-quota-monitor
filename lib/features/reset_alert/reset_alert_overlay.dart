import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/reset_alert_controller.dart';
import '../../app/theme.dart';
import '../../core/reset_alert.dart';

class ResetAlertHost extends ConsumerWidget {
  const ResetAlertHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(resetAlertProvider).value;
    return ResetAlertOverlay(
      state: value ?? const ResetAlertState(),
      onCollapse: () => unawaited(
        ref.read(resetAlertProvider.notifier).collapseToWatermark(),
      ),
      onShowDetails: () =>
          unawaited(ref.read(resetAlertProvider.notifier).showDialog()),
      onForceDismiss: () =>
          unawaited(ref.read(resetAlertProvider.notifier).forceDismiss()),
      child: child,
    );
  }
}

class ResetAlertOverlay extends StatelessWidget {
  const ResetAlertOverlay({
    required this.state,
    required this.onCollapse,
    required this.onShowDetails,
    required this.onForceDismiss,
    required this.child,
    super.key,
  });

  final ResetAlertState state;
  final VoidCallback onCollapse;
  final VoidCallback onShowDetails;
  final VoidCallback onForceDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final announcements = state.announcements;
    if (announcements.isEmpty ||
        state.presentation == ResetAlertPresentation.hidden) {
      return child;
    }
    final isDialog = state.presentation == ResetAlertPresentation.dialog;
    return PopScope(
      canPop: !isDialog,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (state.presentation == ResetAlertPresentation.watermark) ...[
            IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('reset-alert-watermark'),
                painter: _ResetWatermarkPainter(_watermarkLabel(announcements)),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + AppSpace.sm,
              right: MediaQuery.paddingOf(context).right + AppSpace.sm,
              child: _WatermarkBadge(
                announcements: announcements,
                onPressed: onShowDetails,
              ),
            ),
          ],
          if (isDialog) ...[
            const ModalBarrier(
              key: ValueKey('reset-alert-modal-barrier'),
              dismissible: false,
              color: Color(0xB307121C),
            ),
            Center(
              child: _ResetAlertDialog(
                announcements: announcements,
                onCollapse: onCollapse,
                onForceDismiss: onForceDismiss,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _watermarkLabel(List<ResetAnnouncement> announcements) {
    if (announcements.length > 1) {
      return 'CODEX ${announcements.length} 条重置提醒';
    }
    final announcement = announcements.single;
    final time = announcement.scheduledFor;
    if (time == null) return 'CODEX 重置提醒';
    return 'CODEX 预计重置 ${DateFormat('MM-dd HH:mm').format(time.toLocal())}';
  }
}

class _ResetAlertDialog extends StatelessWidget {
  const _ResetAlertDialog({
    required this.announcements,
    required this.onCollapse,
    required this.onForceDismiss,
  });

  final List<ResetAnnouncement> announcements;
  final VoidCallback onCollapse;
  final VoidCallback onForceDismiss;

  @override
  Widget build(BuildContext context) {
    final maxHeight = math.max(
      240.0,
      MediaQuery.sizeOf(context).height - AppSpace.lg * 2,
    );
    final trackerNames = announcements
        .map((announcement) => announcement.trackerName)
        .toSet()
        .join(' / ');
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: maxHeight),
        child: Card(
          margin: const EdgeInsets.all(AppSpace.lg),
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.warning, width: 1.5),
            borderRadius: BorderRadius.circular(AppSpace.radius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.warning,
                        size: 30,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          announcements.length == 1
                              ? '检测到 Codex ${announcements.single.resetType == 'banked' ? '储存重置' : '全局重置'}公告'
                              : '检测到 ${announcements.length} 条 Codex 重置公告',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  for (final announcement in announcements) ...[
                    _AnnouncementPanel(announcement: announcement),
                    if (announcement != announcements.last)
                      const SizedBox(height: AppSpace.sm),
                  ],
                  const SizedBox(height: AppSpace.md),
                  const Text(
                    '这是公开公告，计划时间经过不代表重置已经完成。应用会在公告消失后自动移除提醒。',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    '数据来源：$trackerNames',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onForceDismiss,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('强制关闭本次提醒'),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      FilledButton.icon(
                        onPressed: onCollapse,
                        icon: const Icon(Icons.layers_outlined),
                        label: const Text('收起并保留水印'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementPanel extends StatelessWidget {
  const _AnnouncementPanel({required this.announcement});

  final ResetAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final scheduledFor = announcement.scheduledFor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpace.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    announcement.trackerName,
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _open(Uri.parse(announcement.trackerUrl)),
                  child: const Text('数据页 ↗'),
                ),
                if (announcement.sourceUrl.isNotEmpty)
                  TextButton(
                    onPressed: () => _open(Uri.parse(announcement.sourceUrl)),
                    child: const Text('原公告 ↗'),
                  ),
              ],
            ),
            Text(
              scheduledFor == null
                  ? '执行时间待公布'
                  : '预计在 ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledFor.toLocal())} 前执行',
              key: ValueKey('reset-alert-time-${announcement.trackerName}'),
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                fontFamily: AppText.mono,
              ),
            ),
            if (announcement.text.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                announcement.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.secondary, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(Uri uri) async {
    const allowedHosts = {
      'codex-resets.com',
      'www.codex-resets.com',
      'betteropc.com',
      'www.betteropc.com',
      'x.com',
      'www.x.com',
      'twitter.com',
      'www.twitter.com',
    };
    if (uri.scheme != 'https' || !allowedHosts.contains(uri.host)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _WatermarkBadge extends StatelessWidget {
  const _WatermarkBadge({required this.announcements, required this.onPressed});

  final List<ResetAnnouncement> announcements;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheduledFor = announcements.first.scheduledFor;
    return Material(
      color: AppColors.card.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.warning),
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        key: const ValueKey('reset-alert-watermark-badge'),
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: AppSpace.xs),
              Text(
                announcements.length > 1
                    ? 'Codex 有 ${announcements.length} 条重置提醒 · 点击查看'
                    : scheduledFor == null
                    ? 'Codex 重置提醒 · 点击查看'
                    : 'Codex 预计 ${DateFormat('MM-dd HH:mm').format(scheduledFor.toLocal())} 前重置 · 点击查看',
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetWatermarkPainter extends CustomPainter {
  const _ResetWatermarkPainter(this.label);

  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0x26D9A85A),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    const horizontalGap = 120.0;
    const verticalGap = 92.0;
    for (
      var y = -verticalGap;
      y < size.height + verticalGap;
      y += verticalGap
    ) {
      for (
        var x = -painter.width;
        x < size.width + painter.width;
        x += painter.width + horizontalGap
      ) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-math.pi / 9);
        painter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ResetWatermarkPainter oldDelegate) =>
      oldDelegate.label != label;
}
