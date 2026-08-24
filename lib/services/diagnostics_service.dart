import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import '../database/app_database.dart';

class DiagnosticsService {
  const DiagnosticsService(this._database);
  final AppDatabase _database;

  Future<String> buildJson() async {
    final info = await PackageInfo.fromPlatform();
    final summary = await _database.diagnosticSummary();
    final document = <String, Object?>{
      'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'app': {
        'name': info.appName,
        'version': info.version,
        'build': info.buildNumber,
      },
      'platform': {
        'os': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
      },
      'database': summary,
      'privacy':
          'Credentials, tokens, account IDs and HTTP authorization headers are excluded.',
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  Future<void> writeTo(String path) async {
    // The document is constructed from an allow-list above, never from auth.json.
    await File(path).writeAsString(await buildJson(), flush: true);
  }
}
