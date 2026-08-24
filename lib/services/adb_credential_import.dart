import 'package:flutter/services.dart';

/// Consumes one credential file staged by the local development ADB script.
///
/// Android only exposes this bridge from a debuggable build. The native side
/// deletes the private staging file before returning, so the JSON only exists
/// in Dart memory long enough to be validated and written to secure storage.
class AdbCredentialImport {
  static const _channel = MethodChannel('codex_monitor/adb_credential_import');

  static Future<String?> consume() =>
      _channel.invokeMethod<String>('consumeStagedCredentials');
}
