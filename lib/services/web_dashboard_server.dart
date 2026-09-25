import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/history_consumption.dart';
import '../core/models.dart';
import '../database/app_database.dart';
import 'device_service.dart';

const webDashboardPort = 8787;

class WebDashboardData {
  const WebDashboardData({
    required this.health,
    required this.refreshSeconds,
    this.usage,
    this.lastSync,
    this.device,
  });

  final String health;
  final int refreshSeconds;
  final CodexUsageResponse? usage;
  final DateTime? lastSync;
  final DeviceStatus? device;
}

typedef WebDashboardDataSource = FutureOr<WebDashboardData> Function();

/// A deliberately read-only LAN dashboard. Only already-projected display
/// values leave the process; credentials and raw API responses are never used.
class WebDashboardServer {
  WebDashboardServer(
    this._database,
    this._dataSource, [
    this._assetPath = 'assets/web/dashboard.html',
  ]);

  final AppDatabase _database;
  final WebDashboardDataSource _dataSource;
  final String _assetPath;
  HttpServer? _server;
  Future<void>? _startFuture;
  String? _page;
  var _requested = false;

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<void> start({int port = webDashboardPort}) {
    _requested = true;
    if (_server != null) return Future.value();
    final pending = _startFuture;
    if (pending != null) return pending;
    late final Future<void> future;
    future = _start(port).whenComplete(() {
      if (identical(_startFuture, future)) _startFuture = null;
    });
    _startFuture = future;
    return future;
  }

  Future<void> _start(int port) async {
    _page ??= await rootBundle.loadString(_assetPath);
    SocketException? lastError;
    for (var attempt = 0; attempt < 8 && _requested; attempt++) {
      try {
        final server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          port,
          shared: false,
        );
        if (!_requested) {
          await server.close(force: true);
          return;
        }
        server.autoCompress = true;
        _server = server;
        unawaited(_serve(server));
        return;
      } on SocketException catch (error) {
        lastError = error;
        if (attempt < 7) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }
    if (_requested && lastError != null) throw lastError;
  }

  Future<void> stop() async {
    _requested = false;
    final server = _server;
    _server = null;
    if (server != null) await server.close(force: true);
  }

  Future<void> configure(bool enabled) => enabled ? start() : stop();

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handle(request));
      }
    } on HttpException {
      // Closing the server ends the request stream with an HttpException on
      // some platforms. A later configure(true) can bind a fresh socket.
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    _securityHeaders(response);
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
      await response.close();
      return;
    }
    try {
      switch (request.uri.path) {
        case '/':
        case '/index.html':
          response.headers.contentType = ContentType.html;
          response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
          if (request.method == 'GET') response.write(_page);
        case '/healthz':
          response.headers.contentType = ContentType.json;
          if (request.method == 'GET') {
            response.write(jsonEncode({'status': 'ok'}));
          }
        case '/api/dashboard':
          response.headers.contentType = ContentType.json;
          response.headers.set(
            HttpHeaders.cacheControlHeader,
            'no-store, max-age=0',
          );
          if (request.method == 'GET') {
            response.write(jsonEncode(await _dashboardJson(request.uri)));
          }
        default:
          response.statusCode = HttpStatus.notFound;
          response.headers.contentType = ContentType.json;
          if (request.method == 'GET') {
            response.write(jsonEncode({'error': 'not_found'}));
          }
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
      response.headers.contentType = ContentType.json;
      if (request.method == 'GET') {
        response.write(jsonEncode({'error': 'dashboard_unavailable'}));
      }
    } finally {
      await response.close();
    }
  }

  Future<Map<String, Object?>> _dashboardJson(Uri uri) async {
    final data = await _dataSource();
    final now = DateTime.now();
    final period = _period(uri, data.usage, now);
    final consumptionUnit = historyConsumptionUnitFor(
      period.end.difference(period.start),
    );
    final observedEnd = period.end.isAfter(now) ? now : period.end;
    final history = observedEnd.isAfter(period.start)
        ? await _database.snapshotsBetween(period.start, observedEnd)
        : const <QuotaSnapshot>[];
    final consumption = historyConsumptionBuckets(
      [
        for (final row in history)
          (
            timestamp: row.timestamp,
            usedPercent: row.usedPercent,
            resetAt: row.resetAt,
            windowDurationSeconds: row.windowDurationSeconds,
          ),
      ],
      start: period.start,
      end: observedEnd,
      unit: consumptionUnit,
    );
    final events = await _database.recentEvents(12);
    return {
      'generatedAt': now.toUtc().toIso8601String(),
      'health': data.health,
      'refreshSeconds': data.refreshSeconds,
      'lastSync': data.lastSync?.toUtc().toIso8601String(),
      'usage': _usageJson(data.usage, now),
      'device': _deviceJson(data.device),
      'period': {
        'kind': period.kind,
        'start': period.start.toUtc().toIso8601String(),
        'end': period.end.toUtc().toIso8601String(),
      },
      'history': [
        for (final row in history)
          {
            'timestamp': row.timestamp.toUtc().toIso8601String(),
            'remainingPercent': row.remainingPercent,
            'usedPercent': row.usedPercent,
          },
      ],
      'consumptionUnitSeconds': consumptionUnit.inSeconds,
      'consumptionHistory': [
        for (final bucket in consumption)
          {
            'timestamp': bucket.timestamp.toUtc().toIso8601String(),
            'consumedPercent': bucket.consumedPercent,
          },
      ],
      'events': [
        for (final event in events)
          {
            'timestamp': event.timestamp.toUtc().toIso8601String(),
            'type': event.type,
            'title': event.title,
            'description': event.description,
          },
      ],
    };
  }

  _WebPeriod _period(Uri uri, CodexUsageResponse? usage, DateTime now) {
    final kind = uri.queryParameters['period'] ?? 'rolling';
    if (kind == 'today') {
      final start = DateTime(now.year, now.month, now.day);
      return _WebPeriod('today', start, start.add(const Duration(days: 1)));
    }
    if (kind == 'refresh') {
      final window = usage?.rateLimit.windows.firstOrNull;
      if (window?.resetAt != null &&
          window?.durationSeconds != null &&
          window!.durationSeconds! > 0) {
        final end = window.resetAt!.toLocal();
        return _WebPeriod(
          'refresh',
          end.subtract(Duration(seconds: window.durationSeconds!)),
          end,
        );
      }
    }
    const allowedHours = {1, 6, 12, 24};
    final requested = int.tryParse(uri.queryParameters['hours'] ?? '24');
    final hours = allowedHours.contains(requested) ? requested! : 24;
    return _WebPeriod('rolling', now.subtract(Duration(hours: hours)), now);
  }

  Map<String, Object?>? _usageJson(CodexUsageResponse? usage, DateTime now) {
    if (usage == null) return null;
    return {
      'planType': usage.planType,
      'windows': usage.rateLimit.windows
          .map((window) => _windowJson(window, now))
          .toList(),
      'additional': [
        for (final item in usage.additional)
          {
            'name': item.displayName,
            'windows': item.rateLimit.windows
                .map((window) => _windowJson(window, now))
                .toList(),
          },
      ],
      'credits': usage.credits == null
          ? null
          : {
              'hasCredits': usage.credits!.hasCredits,
              'unlimited': usage.credits!.unlimited,
              'balance': usage.credits!.balance,
            },
      'resetCredits': usage.resetCredits,
      'resetCards': usage.resetCards == null
          ? null
          : [
              for (final card in usage.resetCards!)
                {
                  'expiresAt': card.expiresAt?.toUtc().toIso8601String(),
                  'supportedByPlan': card.supportedByPlan,
                },
            ],
    };
  }

  Map<String, Object?> _windowJson(RateWindow window, DateTime now) => {
    'usedPercent': window.usedPercent,
    'remainingPercent': window.remainingPercent,
    'durationSeconds': window.durationSeconds,
    'resetAt': window.resetAt?.toUtc().toIso8601String(),
    'timeRemainingPercent': window.timeRemainingPercent(now),
  };

  Map<String, Object?>? _deviceJson(DeviceStatus? device) => device == null
      ? null
      : {
          'uptimeSeconds': device.uptime.inSeconds,
          'charging': device.charging,
          'full': device.full,
          'memoryMb': device.memoryMb,
          'temperatureC': device.temperature,
          'wifiIp': device.wifiIp,
        };

  void _securityHeaders(HttpResponse response) {
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Referrer-Policy', 'no-referrer');
    response.headers.set('X-Frame-Options', 'DENY');
    response.headers.set(
      'Content-Security-Policy',
      "default-src 'self'; style-src 'self' 'unsafe-inline'; "
          "script-src 'self' 'unsafe-inline'; connect-src 'self'; "
          "img-src 'self' data:; frame-ancestors 'none'",
    );
  }
}

class _WebPeriod {
  const _WebPeriod(this.kind, this.start, this.end);

  final String kind;
  final DateTime start;
  final DateTime end;
}
