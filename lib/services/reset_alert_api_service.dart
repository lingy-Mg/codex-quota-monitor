import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../core/reset_alert.dart';
import 'network_proxy_service.dart';

abstract interface class ResetAlertClient {
  String get sourceName;

  Future<ResetAlertFetchResult> fetch({String? etag});

  void close({bool force = false});
}

class ResetAlertFetchResult {
  const ResetAlertFetchResult({
    required this.announcement,
    this.etag,
    this.notModified = false,
  });

  const ResetAlertFetchResult.notModified({this.etag})
    : announcement = null,
      notModified = true;

  final ResetAnnouncement? announcement;
  final String? etag;
  final bool notModified;
}

class ResetAlertApiException implements Exception {
  const ResetAlertApiException(this.statusCode, {this.retryAfter});

  final int? statusCode;
  final Duration? retryAfter;
}

class ResetAlertApiService implements ResetAlertClient {
  ResetAlertApiService([Dio? dio, NetworkProxyService? proxyService])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (status) => status != null && status < 600,
            ),
          ),
      _proxyService = proxyService ?? const NetworkProxyService() {
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = _findProxy,
    );
  }

  static const statusUrl = 'https://codex-resets.com/api/v1/status';

  @override
  String get sourceName => 'Codex Resets';

  final Dio _dio;
  final NetworkProxyService _proxyService;
  NetworkProxy? _activeProxy;

  String _findProxy(Uri uri) => _activeProxy?.findProxy(uri) ?? 'DIRECT';

  @override
  Future<ResetAlertFetchResult> fetch({String? etag}) async {
    _activeProxy = await _proxyService.activeProxy();
    final response = await _dio.get<dynamic>(
      statusUrl,
      options: Options(
        headers: {
          'Accept': 'application/json',
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

    final decoded = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (decoded is! Map) {
      throw const FormatException('Invalid reset status response');
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw const FormatException('Missing reset status data');
    }
    final scheduled = data['scheduled_reset'];
    return ResetAlertFetchResult(
      announcement: scheduled is Map
          ? ResetAnnouncement.fromJson(
              Map<String, dynamic>.from(scheduled),
              defaultTrackerName: sourceName,
              defaultTrackerUrl: 'https://codex-resets.com',
            )
          : null,
      etag: responseEtag,
    );
  }

  Duration? _retryAfter(String? raw) {
    final seconds = int.tryParse(raw ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  @override
  void close({bool force = false}) => _dio.close(force: force);
}
