import 'dart:io';

/// Locates the credentials that the Codex CLI keeps for the current Windows
/// user. The contents are deliberately returned only to the caller so they can
/// be placed in secure storage; this service never logs or persists them.
class LocalAuthFileService {
  const LocalAuthFileService();

  static bool get supportsAutomaticDiscovery => Platform.isWindows;

  static String? windowsAuthPath({
    bool? isWindows,
    Map<String, String>? environment,
  }) {
    if (!(isWindows ?? Platform.isWindows)) return null;
    final variables = environment ?? Platform.environment;
    final profile = variables['USERPROFILE'] ?? variables['HOME'];
    if (profile == null || profile.trim().isEmpty) return null;
    return '${profile.trim()}\\.codex\\auth.json';
  }

  /// Returns null when the standard file is absent. I/O failures are allowed to
  /// reach the UI so it can keep the manual import option available.
  Future<String?> readWindowsAuthJson() async {
    final path = windowsAuthPath();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}
