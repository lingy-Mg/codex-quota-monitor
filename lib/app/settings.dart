import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.refreshSeconds = 30,
    this.keepAwake = true,
    this.burnInProtection = true,
    this.immersive = true,
    this.historyDays = 60,
    this.historyRangeMinutes = 24 * 60,
    this.bootMonitoring = false,
  });
  final int refreshSeconds, historyDays, historyRangeMinutes;
  final bool keepAwake, burnInProtection, immersive, bootMonitoring;
  AppSettings copyWith({
    int? refreshSeconds,
    int? historyDays,
    int? historyRangeMinutes,
    bool? keepAwake,
    bool? burnInProtection,
    bool? immersive,
    bool? bootMonitoring,
  }) => AppSettings(
    refreshSeconds: refreshSeconds ?? this.refreshSeconds,
    historyDays: historyDays ?? this.historyDays,
    historyRangeMinutes: historyRangeMinutes ?? this.historyRangeMinutes,
    keepAwake: keepAwake ?? this.keepAwake,
    burnInProtection: burnInProtection ?? this.burnInProtection,
    immersive: immersive ?? this.immersive,
    bootMonitoring: bootMonitoring ?? this.bootMonitoring,
  );
  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      refreshSeconds: p.getInt('refreshSeconds') ?? 30,
      historyDays: p.getInt('historyDays') ?? 60,
      historyRangeMinutes: p.getInt('historyRangeMinutes') ?? 24 * 60,
      keepAwake: p.getBool('keepAwake') ?? true,
      burnInProtection: p.getBool('burnInProtection') ?? true,
      immersive: p.getBool('immersive') ?? true,
      bootMonitoring: p.getBool('bootMonitoring') ?? false,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('refreshSeconds', refreshSeconds);
    await p.setInt('historyDays', historyDays);
    await p.setInt('historyRangeMinutes', historyRangeMinutes);
    await p.setBool('keepAwake', keepAwake);
    await p.setBool('burnInProtection', burnInProtection);
    await p.setBool('immersive', immersive);
    await p.setBool('bootMonitoring', bootMonitoring);
  }
}
