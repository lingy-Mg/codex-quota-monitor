import 'package:codex_quota_monitor/services/reset_alert_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a scheduled reset and sends the cached ETag', () async {
    final dio = Dio();
    final service = ResetAlertApiService(dio);
    addTearDown(service.close);
    String? ifNoneMatch;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          ifNoneMatch = request.headers['If-None-Match']?.toString();
          handler.resolve(
            Response<dynamic>(
              requestOptions: request,
              statusCode: 200,
              headers: Headers.fromMap({
                'etag': ['"current"'],
              }),
              data: {
                'data': {
                  'scheduled_reset': {
                    'id': 'announcement-1',
                    'status': 'scheduled',
                    'reset_type': 'regular',
                    'announced_at': '2026-09-22T04:31:32Z',
                    'scheduled_for': '2026-09-23T07:00:00Z',
                    'text': 'Reset lands by midnight.',
                    'source': {
                      'type': 'x_post',
                      'author': 'thsottiaux',
                      'url': 'https://example.com/post',
                    },
                  },
                },
              },
            ),
          );
        },
      ),
    );

    final result = await service.fetch(etag: '"previous"');

    expect(ifNoneMatch, '"previous"');
    expect(result.etag, '"current"');
    expect(result.announcement?.id, 'announcement-1');
    expect(result.announcement?.scheduledFor, DateTime.utc(2026, 9, 23, 7));
  });

  test('keeps 304 distinct from an empty scheduled reset', () async {
    final dio = Dio();
    final service = ResetAlertApiService(dio);
    addTearDown(service.close);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response<dynamic>(requestOptions: request, statusCode: 304),
        ),
      ),
    );

    final result = await service.fetch(etag: '"same"');

    expect(result.notModified, isTrue);
    expect(result.etag, '"same"');
  });
}
