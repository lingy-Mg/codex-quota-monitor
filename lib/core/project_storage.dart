import 'dart:io';

/// Paths for non-sensitive application data that should be visible in the
/// Windows project root during local development.
class ProjectStorage {
  const ProjectStorage._();

  static bool get usesProjectRoot => Platform.isWindows;

  static String filePath(String fileName) =>
      File('${projectRoot.path}${Platform.pathSeparator}$fileName').path;

  static String get databasePath => filePath('codex_monitor.sqlite');

  static String get settingsPath => filePath('codex_monitor_settings.json');

  static Directory get projectRoot {
    final workingDirectory = Directory.current.absolute;
    if (_hasPubspec(workingDirectory)) return workingDirectory;

    var candidate = File(Platform.resolvedExecutable).parent.absolute;
    while (true) {
      if (_hasPubspec(candidate)) return candidate;
      final parent = candidate.parent;
      if (parent.path == candidate.path) break;
      candidate = parent;
    }
    return workingDirectory;
  }

  static bool _hasPubspec(Directory directory) => File(
    '${directory.path}${Platform.pathSeparator}pubspec.yaml',
  ).existsSync();
}
