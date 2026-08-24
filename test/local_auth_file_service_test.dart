import 'package:codex_quota_monitor/services/local_auth_file_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalAuthFileService', () {
    test('uses the current Windows profile Codex auth location', () {
      expect(
        LocalAuthFileService.windowsAuthPath(
          isWindows: true,
          environment: {'USERPROFILE': r'C:\Users\alice'},
        ),
        r'C:\Users\alice\.codex\auth.json',
      );
    });

    test('uses HOME only when USERPROFILE is unavailable', () {
      expect(
        LocalAuthFileService.windowsAuthPath(
          isWindows: true,
          environment: {'HOME': r'D:\Profiles\alice'},
        ),
        r'D:\Profiles\alice\.codex\auth.json',
      );
    });

    test('does not discover an auth file outside Windows', () {
      expect(
        LocalAuthFileService.windowsAuthPath(
          isWindows: false,
          environment: {'USERPROFILE': r'C:\Users\alice'},
        ),
        isNull,
      );
    });
  });
}
