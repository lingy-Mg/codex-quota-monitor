import 'dart:convert';
import 'dart:io';

import 'package:codex_quota_monitor/core/models.dart';
import 'package:codex_quota_monitor/database/app_database.dart';
import 'package:codex_quota_monitor/services/device_service.dart';
import 'package:codex_quota_monitor/services/web_dashboard_server.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LAN dashboard serves the full projected view without secrets', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.now();
    final usage = CodexUsageResponse.fromJson(
      {
        'plan_type': 'pro',
        'rate_limit': {
          'primary_window': {
            'used_percent': 32,
            'limit_window_seconds': 18000,
            'reset_at':
                now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
                1000,
          },
        },
        'additional_rate_limits': [
          {
            'limit_name': 'GPT-5.3-Codex-Spark',
            'rate_limit': {
              'primary_window': {
                'used_percent': 17,
                'limit_window_seconds': 18000,
              },
            },
          },
        ],
        'credits': {'has_credits': true, 'balance': '12.50'},
      },
      resetDetails: {
        'available_count': 1,
        'credits': [
          {
            'status': 'available',
            'expires_at': now.add(const Duration(days: 8)).toIso8601String(),
          },
        ],
      },
    );
    await database.saveUsage(usage, now.subtract(const Duration(minutes: 5)));
    final server = WebDashboardServer(
      database,
      () => WebDashboardData(
        health: 'live',
        refreshSeconds: 30,
        usage: usage,
        lastSync: now,
        device: DeviceStatus(
          uptime: const Duration(hours: 12),
          charging: true,
          full: false,
          memoryMb: 128.4,
          wifiIp: '192.168.1.23',
        ),
      ),
    );
    await server.start(port: 0);
    addTearDown(server.stop);

    final result = await HttpOverrides.runZoned(() async {
      final client = HttpClient();
      final response = await (await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}/api/dashboard?period=rolling&hours=24',
        ),
      )).close();
      final body = await utf8.decodeStream(response);
      final pageResponse = await (await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/'),
      )).close();
      final page = await utf8.decodeStream(pageResponse);
      client.close(force: true);
      return (
        status: response.statusCode,
        body: body,
        pageStatus: pageResponse.statusCode,
        page: page,
      );
    }, createHttpClient: _RealHttpOverrides().createHttpClient);
    final body = result.body;
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(result.status, HttpStatus.ok);
    expect(json['health'], 'live');
    expect(json['history'], isNotEmpty);
    expect(json['events'], isNotEmpty);
    expect(json['device']['wifiIp'], '192.168.1.23');
    expect(json['usage']['windows'][0]['remainingPercent'], 68);
    expect(json['usage']['additional'][0]['name'], 'Codex Spark');
    expect(json['usage']['credits']['balance'], '12.50');
    expect(json['usage']['resetCards'], hasLength(1));
    expect(body, isNot(contains('access_token')));
    expect(body, isNot(contains('refresh_token')));
    expect(body, isNot(contains('account_id')));

    expect(result.pageStatus, HttpStatus.ok);
    expect(result.page, contains('Codex 额度监控'));
    expect(result.page, contains('/api/dashboard'));
    expect(result.page, contains('width:1280px;height:800px'));
    expect(result.page, contains('overflow:hidden'));
    expect(result.page, contains('Math.min(1,innerWidth/designWidth'));
  });
}

class _RealHttpOverrides extends HttpOverrides {}
