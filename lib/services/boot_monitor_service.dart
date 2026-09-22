import 'package:flutter/services.dart';

/// The native service owns the user-visible notification and BOOT_COMPLETED
/// lifecycle. Dart only requests an explicit opt-in/out; it never sends a
/// credential to Android.
class BootMonitorService {
  static const _channel = MethodChannel('codex_monitor/foreground_monitor');

  static Future<void> configure({
    required bool bootMonitoring,
    required bool webServerEnabled,
  }) => _channel.invokeMethod<void>('setModes', {
    'bootMonitoring': bootMonitoring,
    'webServerEnabled': webServerEnabled,
  });

  static Future<void> publishRemaining(String text) =>
      _channel.invokeMethod<void>('updateNotification', {'remaining': text});
}
