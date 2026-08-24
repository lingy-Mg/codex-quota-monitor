import 'package:flutter/services.dart';

/// The native service owns the user-visible notification and BOOT_COMPLETED
/// lifecycle. Dart only requests an explicit opt-in/out; it never sends a
/// credential to Android.
class BootMonitorService {
  static const _channel = MethodChannel('codex_monitor/foreground_monitor');

  static Future<void> setEnabled(bool enabled) =>
      _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});

  static Future<void> publishRemaining(String text) =>
      _channel.invokeMethod<void>('updateNotification', {'remaining': text});
}
