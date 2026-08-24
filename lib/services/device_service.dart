import 'package:flutter/services.dart';

class DeviceStatus {
  const DeviceStatus({
    required this.uptime,
    required this.charging,
    required this.full,
    this.temperature,
  });
  final Duration uptime;
  final bool charging;
  final bool full;
  final double? temperature;
}

class DeviceService {
  static const _channel = MethodChannel('codex_monitor/device');
  Future<DeviceStatus> status() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('status');
    return DeviceStatus(
      uptime: Duration(seconds: raw?['uptimeSeconds'] as int? ?? 0),
      charging: raw?['charging'] as bool? ?? false,
      full: raw?['full'] as bool? ?? false,
      temperature: (raw?['temperatureC'] as num?)?.toDouble(),
    );
  }
}
