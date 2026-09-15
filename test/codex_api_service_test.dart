import 'package:codex_quota_monitor/core/models.dart';
import 'package:codex_quota_monitor/services/codex_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const credentials = CodexCredentials(
    accessToken: '',
    refreshToken: '',
    accountId: '',
  );
  for (final status in [200, 401, 503]) {
    test('usage integrates reset detail response $status', () async {
      final dio = Dio();
      final service = CodexApiService(dio);
      addTearDown(service.close);
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            paths.add(request.path);
            final isUsage = request.path == CodexEndpoints.usage;
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: isUsage ? 200 : status,
                data: isUsage
                    ? {
                        'rate_limit': {
                          'primary_window': {'used_percent': 20},
                        },
                        'rate_limit_reset_credits': {'available_count': 2},
                      }
                    : {
                        'available_count': 1,
                        'credits': [
                          {
                            'status': 'available',
                            'expires_at': '2026-09-18T12:00:00Z',
                          },
                        ],
                      },
              ),
            );
          },
        ),
      );
      if (status == 401) {
        await expectLater(
          service.usage(credentials),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 401),
          ),
        );
      } else {
        final result = await service.usage(credentials);
        expect(result.rateLimit.windows.single.remainingPercent, 80);
        expect(result.resetCredits, status == 200 ? 1 : 2);
        expect(result.resetCards?.length, status == 200 ? 1 : null);
      }
      expect(paths, [CodexEndpoints.usage, CodexEndpoints.resetCredits]);
    });
  }
}
