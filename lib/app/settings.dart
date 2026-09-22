import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import '../core/project_storage.dart';

class AppSettings {
  const AppSettings({
    this.refreshSeconds = 30,
    this.keepAwake = true,
    this.burnInProtection = true,
    this.immersive = true,
    this.historyDays = 60,
    this.historyRangeMinutes = 24 * 60,
    this.bootMonitoring = false,
    this.webServerEnabled = false,
  });
  final int refreshSeconds, historyDays, historyRangeMinutes;
  final bool keepAwake,
      burnInProtection,
      immersive,
      bootMonitoring,
      webServerEnabled;
  AppSettings copyWith({
    int? refreshSeconds,
    int? historyDays,
    int? historyRangeMinutes,
    bool? keepAwake,
    bool? burnInProtection,
    bool? immersive,
    bool? bootMonitoring,
    bool? webServerEnabled,
  }) => AppSettings(
    refreshSeconds: refreshSeconds ?? this.refreshSeconds,
    historyDays: historyDays ?? this.historyDays,
    historyRangeMinutes: historyRangeMinutes ?? this.historyRangeMinutes,
    keepAwake: keepAwake ?? this.keepAwake,
    burnInProtection: burnInProtection ?? this.burnInProtection,
    immersive: immersive ?? this.immersive,
    bootMonitoring: bootMonitoring ?? this.bootMonitoring,
    webServerEnabled: webServerEnabled ?? this.webServerEnabled,
  );
  static Future<AppSettings> load() async {
    if (ProjectStorage.usesProjectRoot) {
      return _loadFromProjectRoot();
    }
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      refreshSeconds: p.getInt('refreshSeconds') ?? 30,
      historyDays: p.getInt('historyDays') ?? 60,
      historyRangeMinutes: p.getInt('historyRangeMinutes') ?? 24 * 60,
      keepAwake: p.getBool('keepAwake') ?? true,
      burnInProtection: p.getBool('burnInProtection') ?? true,
      immersive: p.getBool('immersive') ?? true,
      bootMonitoring: p.getBool('bootMonitoring') ?? false,
      webServerEnabled: p.getBool('webServerEnabled') ?? false,
    );
  }

  Future<void> save() async {
    if (ProjectStorage.usesProjectRoot) {
      final file = File(ProjectStorage.settingsPath);
      await file.writeAsString(
        jsonEncode({
          'refreshSeconds': refreshSeconds,
          'historyDays': historyDays,
          'historyRangeMinutes': historyRangeMinutes,
          'keepAwake': keepAwake,
          'burnInProtection': burnInProtection,
          'immersive': immersive,
          'bootMonitoring': bootMonitoring,
          'webServerEnabled': webServerEnabled,
        }),
        flush: true,
      );
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setInt('refreshSeconds', refreshSeconds);
    await p.setInt('historyDays', historyDays);
    await p.setInt('historyRangeMinutes', historyRangeMinutes);
    await p.setBool('keepAwake', keepAwake);
    await p.setBool('burnInProtection', burnInProtection);
    await p.setBool('immersive', immersive);
    await p.setBool('bootMonitoring', bootMonitoring);
    await p.setBool('webServerEnabled', webServerEnabled);
  }

  static Future<AppSettings> _loadFromProjectRoot() async {
    final file = File(ProjectStorage.settingsPath);
    if (!await file.exists()) return const AppSettings();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return const AppSettings();
      return AppSettings(
        refreshSeconds: _int(json['refreshSeconds'], 30),
        historyDays: _int(json['historyDays'], 60),
        historyRangeMinutes: _int(json['historyRangeMinutes'], 24 * 60),
        keepAwake: _bool(json['keepAwake'], true),
        burnInProtection: _bool(json['burnInProtection'], true),
        immersive: _bool(json['immersive'], true),
        bootMonitoring: _bool(json['bootMonitoring'], false),
        webServerEnabled: _bool(json['webServerEnabled'], false),
      );
    } on FormatException {
      return const AppSettings();
    } on FileSystemException {
      return const AppSettings();
    }
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;
}
