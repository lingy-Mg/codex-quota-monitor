import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../core/reset_alert.dart';
import 'reset_alert_api_service.dart';

class BetterOpcResetService implements ResetAlertClient {
  BetterOpcResetService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              responseType: ResponseType.plain,
              validateStatus: (status) => status != null && status < 600,
            ),
          ) {
    // BetterOPC is hosted in mainland China and can fail its TLS handshake
    // through some HTTP proxies. A direct socket still follows VPN routing.
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
    );
  }

  static const pageUrl =
      'https://betteropc.com/ai-products/reset-signals/codex';

  final Dio _dio;

  @override
  String get sourceName => 'BetterOPC';

  @override
  Future<ResetAlertFetchResult> fetch({String? etag}) async {
    final response = await _dio.get<String>(
      pageUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Accept': 'text/html',
          'User-Agent': 'code-use-app/1.0',
          if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
        },
      ),
    );
    final responseEtag = response.headers.value('etag') ?? etag;
    if (response.statusCode == HttpStatus.notModified) {
      return ResetAlertFetchResult.notModified(etag: responseEtag);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw ResetAlertApiException(
        response.statusCode,
        retryAfter: _retryAfter(response.headers.value('retry-after')),
      );
    }

    return ResetAlertFetchResult(
      announcement: parse(response.data ?? ''),
      etag: responseEtag,
    );
  }

  ResetAnnouncement? parse(String html) {
    const scheduledMarker = 'product-tracking-scheduled-reset';
    final marker = html.indexOf(scheduledMarker);
    if (marker < 0) return null;
    final itemStart = html.lastIndexOf('<li', marker);
    final itemEnd = html.indexOf('</li>', marker);
    if (itemStart < 0 || itemEnd < 0) {
      throw const FormatException('Invalid BetterOPC scheduled reset');
    }
    final item = html.substring(itemStart, itemEnd);
    final id = _first(item, RegExp(r'data-signal-id="([^"]+)"'));
    final status = _first(item, RegExp(r'data-signal-reset-status="([^"]+)"'));
    final sourceUrl = _first(
      item,
      RegExp(r'href="(https://(?:x\.com|twitter\.com)/[^"]+)"'),
    );
    final targetIso = _first(html, RegExp(r'targetIso\\":\\"([^"\\]+)'));
    final publishedAtIso = _first(
      html,
      RegExp(r'publishedAtIso\\":\\"([^"\\]+)'),
    );
    final scheduledFor = DateTime.tryParse(targetIso ?? '');
    final announcedAt = DateTime.tryParse(publishedAtIso ?? '');
    if (id == null ||
        status != 'scheduled' ||
        sourceUrl == null ||
        scheduledFor == null ||
        announcedAt == null) {
      throw const FormatException('Incomplete BetterOPC scheduled reset');
    }
    final evidence = _plainText(
      _first(
            item,
            RegExp(
              r'<p class="product-tracking-scheduled-reset-evidence">(.*?)</p>',
              dotAll: true,
            ),
          ) ??
          'BetterOPC 已标记为已排期',
    );
    final isBanked = item.contains('发重置卡') || item.contains('banked');
    return ResetAnnouncement(
      id: id,
      resetType: isBanked ? 'banked' : 'regular',
      announcedAt: announcedAt.toUtc(),
      scheduledFor: scheduledFor.toUtc(),
      text: evidence,
      sourceUrl: sourceUrl,
      trackerName: sourceName,
      trackerUrl: pageUrl,
    );
  }

  String? _first(String input, RegExp pattern) =>
      pattern.firstMatch(input)?.group(1);

  String _plainText(String input) => input
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .trim();

  Duration? _retryAfter(String? raw) {
    final seconds = int.tryParse(raw ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  @override
  void close({bool force = false}) => _dio.close(force: force);
}
