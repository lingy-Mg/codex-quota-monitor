import 'package:codex_quota_monitor/services/network_proxy_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the active Android proxy except for its exclusion list', () {
    const proxy = NetworkProxy(
      host: '127.0.0.1',
      port: 7890,
      exclusionList: ['localhost', '*.local', '10.*'],
    );

    expect(
      proxy.findProxy(Uri.parse('https://chatgpt.com')),
      'PROXY 127.0.0.1:7890',
    );
    expect(proxy.findProxy(Uri.parse('http://localhost:8080')), 'DIRECT');
    expect(proxy.findProxy(Uri.parse('https://printer.local')), 'DIRECT');
    expect(proxy.findProxy(Uri.parse('http://10.0.0.1')), 'DIRECT');
  });
}
