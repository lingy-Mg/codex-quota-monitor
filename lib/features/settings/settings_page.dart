import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/monitor_controller.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../services/diagnostics_service.dart';
import '../../services/web_dashboard_server.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  Future<void> _import(BuildContext c, WidgetRef r) async {
    final f = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = f?.files.single.bytes;
    if (bytes != null) {
      try {
        await r
            .read(dashboardProvider.notifier)
            .importCredentials(utf8.decode(bytes));
        if (c.mounted) {
          ScaffoldMessenger.of(
            c,
          ).showSnackBar(const SnackBar(content: Text('凭据已更新')));
        }
      } catch (_) {
        if (c.mounted) {
          ScaffoldMessenger.of(
            c,
          ).showSnackBar(const SnackBar(content: Text('auth.json 无效')));
        }
      }
    }
  }

  Future<void> _exportDiagnostics(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出诊断日志',
      fileName:
          'codex-monitor-diagnostics-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    try {
      await DiagnosticsService(ref.read(databaseProvider)).writeTo(path);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已导出脱敏诊断日志')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('诊断日志导出失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final dashboard = ref.watch(dashboardProvider).value;
    Future<void> set(AppSettings s) async {
      await ref.read(settingsProvider.notifier).saveSettings(s);
      await ref.read(dashboardProvider.notifier).applyDisplay(s);
    }

    final webAddress =
        'http://${dashboard?.device?.wifiIp ?? '平板 Wi-Fi IP'}:$webDashboardPort';

    Future<void> setWebServer(bool enabled) async {
      try {
        await ref.read(webDashboardServerProvider).configure(enabled);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Web 服务器启动失败，请检查端口是否被占用')),
          );
        }
        return;
      }
      await set(settings.copyWith(webServerEnabled: enabled));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), backgroundColor: AppColors.card),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const _Title('Codex 账号'),
          _line('当前套餐', dashboard?.usage?.planType ?? '--'),
          ListTile(
            title: const Text('重新导入 auth.json'),
            leading: const Icon(Icons.file_open_outlined),
            onTap: () => _import(context, ref),
          ),
          ListTile(
            title: const Text('立即刷新'),
            leading: const Icon(Icons.refresh),
            onTap: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
          ListTile(
            title: const Text('删除凭据'),
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            onTap: () async {
              final keep = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('删除凭据？'),
                  content: const Text('可选择是否保留本机历史监控数据。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('删除并保留历史'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('删除全部'),
                    ),
                  ],
                ),
              );
              if (keep != null) {
                await ref
                    .read(dashboardProvider.notifier)
                    .deleteCredentials(keepHistory: keep);
              }
            },
          ),
          const _Title('监控'),
          DropdownButtonFormField<int>(
            initialValue: settings.refreshSeconds,
            decoration: const InputDecoration(labelText: '刷新频率'),
            items: const [15, 30, 60, 120, 300]
                .map((x) => DropdownMenuItem(value: x, child: Text('$x 秒')))
                .toList(),
            onChanged: (v) {
              if (v != null) set(settings.copyWith(refreshSeconds: v));
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('屏幕常亮'),
            value: settings.keepAwake,
            onChanged: (v) => set(settings.copyWith(keepAwake: v)),
          ),
          SwitchListTile(
            title: const Text('防烧屏微位移'),
            subtitle: const Text('每 10 分钟在 ±2px 内轻微偏移'),
            value: settings.burnInProtection,
            onChanged: (v) => set(settings.copyWith(burnInProtection: v)),
          ),
          SwitchListTile(
            title: const Text('沉浸模式'),
            value: settings.immersive,
            onChanged: (v) => set(settings.copyWith(immersive: v)),
          ),
          SwitchListTile(
            title: const Text('开机启动监控'),
            subtitle: const Text('开启后只恢复低优先级前台采集服务，不会自动打开界面'),
            value: settings.bootMonitoring,
            onChanged: (v) => set(settings.copyWith(bootMonitoring: v)),
          ),
          const _Title('Web 服务器'),
          SwitchListTile(
            title: const Text('允许局域网 Web 查看'),
            subtitle: const Text('只读展示完整仪表盘；开启后由前台服务保持后台运行'),
            value: settings.webServerEnabled,
            onChanged: setWebServer,
          ),
          if (settings.webServerEnabled)
            ListTile(
              title: const Text('电脑访问地址'),
              subtitle: Text(
                webAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: const Icon(Icons.lan_outlined),
              trailing: IconButton(
                tooltip: '复制地址',
                icon: const Icon(Icons.copy_outlined),
                onPressed: dashboard?.device?.wifiIp == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: webAddress),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Web 地址已复制')),
                          );
                        }
                      },
              ),
            ),
          const _Title('历史数据'),
          DropdownButtonFormField<int>(
            initialValue: settings.historyDays,
            decoration: const InputDecoration(labelText: '历史数据保留天数'),
            items: const [7, 30, 60]
                .map((x) => DropdownMenuItem(value: x, child: Text('$x 天')))
                .toList(),
            onChanged: (v) {
              if (v != null) set(settings.copyWith(historyDays: v));
            },
          ),
          ListTile(
            title: const Text('清空历史记录'),
            leading: const Icon(Icons.delete_sweep_outlined),
            onTap: () async {
              await ref.read(databaseProvider).clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('历史记录已清空')));
              }
            },
          ),
          ListTile(
            title: const Text('导出诊断日志'),
            subtitle: const Text('仅含版本、系统与数据库汇总；不含凭据、账号或请求头'),
            leading: const Icon(Icons.file_download_outlined),
            onTap: () => _exportDiagnostics(context, ref),
          ),
          const _Title('关于'),
          const ListTile(
            title: Text('Codex 额度监控'),
            subtitle: Text('纯本地运行。诊断数据不包含凭据或 Authorization 请求头。'),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.cyan,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _line(String a, String b) => ListTile(
  title: Text(a),
  trailing: Text(b, style: const TextStyle(color: AppColors.muted)),
);
