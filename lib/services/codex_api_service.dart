import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../core/models.dart';
import 'network_proxy_service.dart';

class CodexEndpoints {
  static const usage = 'https://chatgpt.com/backend-api/wham/usage';
  static const fallbackUsage = 'https://chatgpt.com/backend-api/codex/usage';
  static const resetCredits =
      'https://chatgpt.com/backend-api/wham/rate-limit-reset-credits';
  static const token = 'https://auth.openai.com/oauth/token';
  static const oauthClientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
}

class ApiException implements Exception {
  ApiException(this.statusCode, {this.retryAfter});
  final int? statusCode;
  final Duration? retryAfter;
  @override
  String toString() => 'API request failed ($statusCode)';
}

class CodexApiService {
  CodexApiService([Dio? dio, NetworkProxyService? proxyService])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (s) => s != null && s < 600,
            ),
          ),
      _proxyService = proxyService ?? const NetworkProxyService() {
    // Dart's HttpClient does not automatically consume Android's per-network
    // ProxyInfo. Keep a single client and ask the current proxy selector for
    // every connection, so VPN/Wi-Fi changes take effect without a restart.
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = _findProxy,
    );
  }
  final Dio _dio;
  final NetworkProxyService _proxyService;
  NetworkProxy? _activeProxy;

  String _findProxy(Uri uri) => _activeProxy?.findProxy(uri) ?? 'DIRECT';

  Future<void> _refreshProxy() async {
    _activeProxy = await _proxyService.activeProxy();
  }

  Options _options(CodexCredentials c) => Options(
    headers: {
      'Authorization': 'Bearer ${c.accessToken}',
      'ChatGPT-Account-Id': c.accountId,
      'User-Agent': 'codex-cli',
      'Accept': 'application/json',
    },
  );
  Future<CodexUsageResponse> usage(CodexCredentials c) async {
    await _refreshProxy();
    var response = await _dio.get(CodexEndpoints.usage, options: _options(c));
    if (response.statusCode == 404 || response.statusCode == 410) {
      response = await _dio.get(
        CodexEndpoints.fallbackUsage,
        options: _options(c),
      );
    }
    if (response.statusCode != 200) throw _failure(response);
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    return CodexUsageResponse.fromJson(data);
  }

  Future<CodexCredentials> refresh(CodexCredentials c) async {
    await _refreshProxy();
    final response = await _dio.post(
      CodexEndpoints.token,
      data: {
        'client_id': CodexEndpoints.oauthClientId,
        'grant_type': 'refresh_token',
        'refresh_token': c.refreshToken,
        'scope': 'openid profile email',
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw _failure(response);
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final access = data['access_token']?.toString();
    if (access == null || access.isEmpty) {
      throw ApiException(response.statusCode);
    }
    return CodexCredentials(
      accessToken: access,
      refreshToken: data['refresh_token']?.toString().isNotEmpty == true
          ? data['refresh_token'].toString()
          : c.refreshToken,
      accountId: c.accountId,
      lastRefresh: DateTime.now().toUtc(),
    );
  }

  ApiException _failure(Response<dynamic> r) {
    final raw = r.headers.value('retry-after');
    return ApiException(
      r.statusCode,
      retryAfter: raw == null
          ? null
          : Duration(seconds: int.tryParse(raw) ?? 0),
    );
  }
}
