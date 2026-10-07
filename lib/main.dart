import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'app/monitor_controller.dart';
import 'app/reset_alert_controller.dart';
import 'app/theme.dart';
import 'app/settings.dart';
import 'core/security.dart';
import 'core/models.dart';
import 'database/app_database.dart';
import 'features/auth/configuration_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/reset_alert/reset_alert_overlay.dart';
import 'services/boot_monitor_service.dart';
import 'services/codex_api_service.dart';
import 'services/adb_credential_import.dart';
import 'services/web_dashboard_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final initialSettings = await AppSettings.load();
  await SystemChrome.setEnabledSystemUIMode(
    initialSettings.immersive
        ? SystemUiMode.immersiveSticky
        : SystemUiMode.edgeToEdge,
  );
  if (initialSettings.keepAwake) {
    await WakelockPlus.enable();
  } else {
    await WakelockPlus.disable();
  }
  runApp(const ProviderScope(child: CodexMonitorApp()));
}

/// Entry point launched by the native opt-in foreground service after boot.
/// It only accesses the same Keystore-backed credentials as the foreground UI
/// and keeps the notification free of account information.
@pragma('vm:entry-point')
void bootMonitorEntrypoint() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final database = AppDatabase();
  final store = CredentialStore();
  final api = CodexApiService();
  var pollInProgress = false;
  CodexUsageResponse? latestUsage;
  DateTime? latestSync;
  var health = MonitorHealth.offline;
  final webServer = WebDashboardServer(database, () async {
    final settings = await AppSettings.load();
    final last = latestUsage == null
        ? await database.lastSnapshots()
        : const <QuotaSnapshot>[];
    return WebDashboardData(
      health: health.name,
      refreshSeconds: settings.refreshSeconds,
      usage: latestUsage ?? (last.isEmpty ? null : usageFromSnapshots(last)),
      lastSync:
          latestSync ??
          (last.isEmpty
              ? null
              : last
                    .map((snapshot) => snapshot.timestamp)
                    .reduce((a, b) => a.isAfter(b) ? a : b)
                    .toLocal()),
    );
  });

  Future<void> poll() async {
    if (pollInProgress) return;
    pollInProgress = true;
    try {
      final credentials = await store.read();
      if (credentials == null) return;
      var current = credentials;
      CodexUsageResponse usage;
      try {
        usage = await api.usage(current);
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        current = await api.refresh(current);
        await store.write(current);
        usage = await api.usage(current);
      }
      final settings = await AppSettings.load();
      await database.saveUsage(
        usage,
        DateTime.now(),
        retentionDays: settings.historyDays,
      );
      latestUsage = usage;
      latestSync = DateTime.now();
      health = MonitorHealth.live;
      final remaining = usage.rateLimit.windows.isEmpty
          ? '--'
          : '${usage.rateLimit.windows.first.remainingPercent?.round() ?? '--'}%';
      await BootMonitorService.publishRemaining(remaining);
    } catch (_) {
      health = MonitorHealth.offline;
      // Failure is intentionally silent here: retry follows the configured
      // cadence and no request metadata/credentials are persisted or logged.
    } finally {
      pollInProgress = false;
    }
  }

  unawaited(poll());
  AppSettings.load().then((settings) {
    if (settings.webServerEnabled) {
      unawaited(webServer.start().catchError((_) {}));
    }
    Timer.periodic(Duration(seconds: settings.refreshSeconds), (_) => poll());
  });
}

class CodexMonitorApp extends ConsumerStatefulWidget {
  const CodexMonitorApp({super.key});
  @override
  ConsumerState<CodexMonitorApp> createState() => _CodexMonitorAppState();
}

class _CodexMonitorAppState extends ConsumerState<CodexMonitorApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_consumeAdbCredentialImport());
  }

  Future<void> _consumeAdbCredentialImport() async {
    try {
      // The controller's initial Keystore read must finish before an ADB
      // import writes new values; otherwise its stale initial state could
      // overwrite the freshly configured dashboard state.
      await ref.read(dashboardProvider.future);
      final authJson = await AdbCredentialImport.consume();
      if (authJson == null || authJson.trim().isEmpty) return;
      await ref.read(dashboardProvider.notifier).importCredentials(authJson);
    } on PlatformException {
      // The bridge is intentionally absent from release builds. Never include
      // credential details in errors or logs.
    } on FormatException {
      // A malformed staged file is consumed and discarded by the native side.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      final settings = ref.read(settingsProvider).value;
      if (settings != null) {
        unawaited(ref.read(dashboardProvider.notifier).applyDisplay(settings));
      }
      ref.read(dashboardProvider.notifier).refresh();
      ref.read(resetAlertProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext c) {
    ref.listen(settingsProvider, (previous, next) {
      final settings = next.value;
      if (settings != null) {
        unawaited(ref.read(dashboardProvider.notifier).applyDisplay(settings));
      }
    });
    final d = ref.watch(dashboardProvider);
    final configured = d.value?.credentials != null;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Codex 额度监控',
      theme: monitorTheme(),
      builder: (context, child) =>
          ResetAlertHost(child: child ?? const SizedBox.shrink()),
      home: configured ? const DashboardPage() : const ConfigurationPage(),
    );
  }
}
