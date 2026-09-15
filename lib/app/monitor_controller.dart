import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/models.dart';
import '../core/security.dart';
import '../database/app_database.dart';
import '../services/codex_api_service.dart';
import '../services/boot_monitor_service.dart';
import '../services/device_service.dart';
import 'settings.dart';

enum MonitorHealth { live, offline, auth, loading }

class DashboardState {
  const DashboardState({
    this.credentials,
    this.usage,
    this.lastSync,
    this.health = MonitorHealth.loading,
    this.error,
    this.device,
    this.events = const [],
  });
  final CodexCredentials? credentials;
  final CodexUsageResponse? usage;
  final DateTime? lastSync;
  final MonitorHealth health;
  final String? error;
  final DeviceStatus? device;
  final List<ActivityEvent> events;
  DashboardState copyWith({
    CodexCredentials? credentials,
    CodexUsageResponse? usage,
    DateTime? lastSync,
    MonitorHealth? health,
    String? error,
    DeviceStatus? device,
    List<ActivityEvent>? events,
    bool clearError = false,
  }) => DashboardState(
    credentials: credentials ?? this.credentials,
    usage: usage ?? this.usage,
    lastSync: lastSync ?? this.lastSync,
    health: health ?? this.health,
    error: clearError ? null : error ?? this.error,
    device: device ?? this.device,
    events: events ?? this.events,
  );
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
final credentialsProvider = Provider<CredentialStore>((_) => CredentialStore());
final apiProvider = Provider<CodexApiService>((ref) {
  final api = CodexApiService();
  ref.onDispose(() => api.close(force: true));
  return api;
});
final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
final dashboardProvider =
    AsyncNotifierProvider<MonitorController, DashboardState>(
      MonitorController.new,
    );
final historyProvider = FutureProvider.family<List<QuotaSnapshot>, Duration>(
  (ref, duration) => ref.read(databaseProvider).snapshots(duration),
);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => AppSettings.load();
  Future<void> saveSettings(AppSettings value) async {
    state = AsyncData(value);
    await value.save();
  }
}

class MonitorController extends AsyncNotifier<DashboardState> {
  Timer? _poller, _deviceTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  var _busy = false;
  var _failures = 0;
  DateTime? _resetRefreshAttempt;
  AppDatabase get _db => ref.read(databaseProvider);
  CredentialStore get _store => ref.read(credentialsProvider);
  CodexApiService get _api => ref.read(apiProvider);
  @override
  Future<DashboardState> build() async {
    final credentials = await _store.read();
    final last = await _db.lastSnapshot();
    final lastUsage = last == null ? null : _usageFromSnapshot(last);
    final initial = DashboardState(
      credentials: credentials,
      usage: lastUsage,
      lastSync: last?.timestamp.toLocal(),
      health: credentials == null
          ? MonitorHealth.auth
          : (last == null ? MonitorHealth.loading : MonitorHealth.offline),
      events: await _db.recentEvents(),
    );
    _connectivity = Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) refresh();
    });
    _deviceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateDevice(),
    );
    _updateDevice();
    if (credentials != null) {
      unawaited(refresh());
      _schedule();
    }
    ref.onDispose(() {
      _poller?.cancel();
      _deviceTimer?.cancel();
      _connectivity?.cancel();
    });
    return initial;
  }

  Future<void> _updateDevice() async {
    try {
      final value = await DeviceService().status();
      final current = state.value;
      if (current != null) state = AsyncData(current.copyWith(device: value));
    } catch (_) {}
  }

  void _schedule([Duration? delay]) {
    _poller?.cancel();
    final seconds = ref.read(settingsProvider).value?.refreshSeconds ?? 30;
    _poller = Timer(delay ?? Duration(seconds: seconds), () async {
      await refresh();
      _schedule();
    });
  }

  Future<void> importCredentials(String authJson) async {
    final credentials = CodexCredentials.fromAuthJson(authJson);
    await _store.write(credentials);
    state = AsyncData(
      (state.value ?? const DashboardState()).copyWith(
        credentials: credentials,
        health: MonitorHealth.loading,
        clearError: true,
      ),
    );
    await refresh();
    _schedule();
  }

  Future<void> deleteCredentials({required bool keepHistory}) async {
    await _store.clear();
    if (!keepHistory) await _db.clearHistory();
    _poller?.cancel();
    final current = state.value ?? const DashboardState();
    state = AsyncData(
      DashboardState(
        health: MonitorHealth.auth,
        device: current.device,
        events: keepHistory ? await _db.recentEvents() : const [],
      ),
    );
  }

  Future<void> refresh({bool resetTriggered = false}) async {
    if (_busy) return;
    final c = state.value?.credentials ?? await _store.read();
    if (c == null) return;
    _busy = true;
    try {
      var active = c;
      CodexUsageResponse usage;
      try {
        usage = await _api.usage(active);
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          active = await _api.refresh(active);
          await _store.write(active);
          await _db.addSystemEvent(
            'token_refresh',
            'Token 自动刷新成功',
            '已使用 refresh token 更新本地登录凭据',
          );
          usage = await _api.usage(active);
        } else {
          rethrow;
        }
      }
      final now = DateTime.now();
      await _db.saveUsage(
        usage,
        now,
        retentionDays: ref.read(settingsProvider).value?.historyDays ?? 60,
      );
      _failures = 0;
      state = AsyncData(
        (state.value ?? const DashboardState()).copyWith(
          credentials: active,
          usage: usage,
          lastSync: now,
          health: MonitorHealth.live,
          clearError: true,
          events: await _db.recentEvents(),
        ),
      );
    } on ApiException catch (e) {
      // Deliberately limited to an HTTP status / network marker. Never expose
      // URLs with query data, headers, account identifiers, or token material.
      debugPrint(
        'Codex usage refresh failed: HTTP ${e.statusCode ?? 'network'}',
      );
      final current = state.value ?? DashboardState(credentials: c);
      if (e.statusCode == 401 || e.statusCode == 400) {
        await _db.addSystemEvent(
          'auth_error',
          'Codex 登录状态已失效',
          '请重新导入 auth.json',
        );
        state = AsyncData(
          current.copyWith(
            health: MonitorHealth.auth,
            error: 'Codex 登录状态已失效，请重新导入 auth.json',
            events: await _db.recentEvents(),
          ),
        );
      } else {
        _failures++;
        final delay =
            e.statusCode == 429 &&
                e.retryAfter != null &&
                e.retryAfter!.inSeconds > 0
            ? e.retryAfter!
            : Duration(seconds: [30, 60, 120, 300][_failures.clamp(1, 4) - 1]);
        _schedule(delay);
        state = AsyncData(
          current.copyWith(
            health: MonitorHealth.offline,
            error: e.statusCode == 429
                ? '请求受限，${delay.inSeconds}秒后重试'
                : '请求失败 (${e.statusCode ?? '网络'})',
          ),
        );
      }
    } catch (error) {
      final category = error is DioException
          ? error.type.name
          : error.runtimeType;
      debugPrint('Codex usage refresh failed: unexpected $category');
      _failures++;
      final current = state.value ?? DashboardState(credentials: c);
      _schedule(
        Duration(seconds: [30, 60, 120, 300][_failures.clamp(1, 4) - 1]),
      );
      state = AsyncData(
        current.copyWith(
          health: MonitorHealth.offline,
          error: '网络不可用，保留最后一次数据',
        ),
      );
    } finally {
      _busy = false;
    }
  }

  void onCountdownEnded() {
    final now = DateTime.now();
    if (_resetRefreshAttempt == null ||
        now.difference(_resetRefreshAttempt!).inMinutes >= 1) {
      _resetRefreshAttempt = now;
      refresh(resetTriggered: true);
    }
  }

  Future<void> applyDisplay(AppSettings values) async {
    if (values.keepAwake) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
    await BootMonitorService.setEnabled(values.bootMonitoring);
    await SystemChrome.setEnabledSystemUIMode(
      values.immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }
}

CodexUsageResponse _usageFromSnapshot(QuotaSnapshot snapshot) =>
    CodexUsageResponse.fromJson({
      'plan_type': snapshot.planType,
      'rate_limit': {
        'primary_window': {
          'used_percent': snapshot.usedPercent,
          'limit_window_seconds': snapshot.windowDurationSeconds,
          'reset_at': snapshot.resetAt == null
              ? null
              : snapshot.resetAt!.millisecondsSinceEpoch ~/ 1000,
        },
      },
    });
