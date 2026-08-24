import 'dart:io';

import 'package:flutter/services.dart';

/// A transient proxy advertised by Android for the currently active network.
/// It is intentionally never persisted: VPN and Wi-Fi proxy settings can
/// change at any time and may be sensitive network configuration.
class NetworkProxy {
  const NetworkProxy({
    required this.host,
    required this.port,
    this.exclusionList = const [],
  });

  final String host;
  final int port;
  final List<String> exclusionList;

  String findProxy(Uri uri) {
    if (_isExcluded(uri.host)) return 'DIRECT';
    return 'PROXY $host:$port';
  }

  bool _isExcluded(String hostToCheck) {
    final host = hostToCheck.toLowerCase();
    return exclusionList.any((rule) {
      final normalized = rule.trim().toLowerCase();
      if (normalized.isEmpty) return false;
      if (normalized.startsWith('*.')) {
        return host.endsWith(normalized.substring(1));
      }
      if (normalized.endsWith('*')) {
        return host.startsWith(normalized.substring(0, normalized.length - 1));
      }
      return host == normalized;
    });
  }
}

class NetworkProxyService {
  const NetworkProxyService();

  static const _channel = MethodChannel('codex_monitor/network_proxy');

  Future<NetworkProxy?> activeProxy() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'activeProxy',
      );
      final host = raw?['host'] as String?;
      final port = raw?['port'] as int?;
      if (host == null || host.isEmpty || port == null || port <= 0) {
        return null;
      }
      final exclusions =
          (raw?['exclusionList'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[];
      return NetworkProxy(host: host, port: port, exclusionList: exclusions);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
