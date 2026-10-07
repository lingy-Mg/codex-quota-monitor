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
          'secondary_window': {
            'used_percent': 54,
            'limit_window_seconds': 604800,
            'reset_at':
                now.add(const Duration(days: 3)).millisecondsSinceEpoch ~/ 1000,
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
    await database.saveUsage(
      CodexUsageResponse.fromJson({
        'rate_limit': {
          'primary_window': {
            'used_percent': 34,
            'limit_window_seconds': 18000,
            'reset_at':
                now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
                1000,
          },
          'secondary_window': {
            'used_percent': 56,
            'limit_window_seconds': 604800,
            'reset_at':
                now.add(const Duration(days: 3)).millisecondsSinceEpoch ~/ 1000,
          },
        },
      }),
      now.subtract(const Duration(minutes: 3)),
    );
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
      final hourlyResponse = await (await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}/api/dashboard?period=rolling&hours=1',
        ),
      )).close();
      final hourlyBody = await utf8.decodeStream(hourlyResponse);
      final cycleResponse = await (await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}/api/dashboard?period=refresh',
        ),
      )).close();
      final cycleBody = await utf8.decodeStream(cycleResponse);
      final pageResponse = await (await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/'),
      )).close();
      final page = await utf8.decodeStream(pageResponse);
      client.close(force: true);
      return (
        status: response.statusCode,
        body: body,
        hourlyBody: hourlyBody,
        cycleBody: cycleBody,
        pageStatus: pageResponse.statusCode,
        page: page,
      );
    }, createHttpClient: _RealHttpOverrides().createHttpClient);
    final body = result.body;
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(result.status, HttpStatus.ok);
    expect(json['health'], 'live');
    expect(json['history'], isNotEmpty);
    expect(json['history'][0]['remainingPercent'], 68);
    expect(json['history'][0]['usedPercent'], 32);
    expect(
      (json['history'] as List).map((row) => row['durationSeconds']),
      containsAll([18000, 604800]),
    );
    expect(json['consumptionUnitSeconds'], 3600);
    expect(jsonDecode(result.hourlyBody)['consumptionUnitSeconds'], 300);
    expect(jsonDecode(result.cycleBody)['consumptionUnitSeconds'], 900);
    expect(json['consumptionHistory'], hasLength(2));
    expect(json['consumptionHistory'][0]['consumedPercent'], 2);
    expect(
      (json['consumptionHistory'] as List).map((row) => row['durationSeconds']),
      [18000, 604800],
    );
    expect(json['events'], isNotEmpty);
    expect(json['device']['wifiIp'], '192.168.1.23');
    expect(json['usage']['windows'][0]['remainingPercent'], 68);
    expect(json['usage']['windows'][1]['remainingPercent'], 46);
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
    expect(result.page, contains('data-mode="consumption"'));
    expect(result.page, contains('额度消耗'));
    expect(result.page, contains('consumptionAxisMax(rows)'));
    expect(result.page, contains('data.consumptionHistory'));
    expect(result.page, contains('secondaryQuota'));
    expect(result.page, contains('quota-segment-fill'));
    expect(result.page, contains('durationSeconds'));
    expect(result.page, contains('2.4s cubic-bezier'));
    expect(result.page, contains('window.rows.forEach'));
  });
}

class _RealHttpOverrides extends HttpOverrides {}
