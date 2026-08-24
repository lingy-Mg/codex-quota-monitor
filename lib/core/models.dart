import 'dart:convert';

double? number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value');
int? integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value');

class CodexCredentials {
  const CodexCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.accountId,
    this.lastRefresh,
  });
  final String accessToken;
  final String refreshToken;
  final String accountId;
  final DateTime? lastRefresh;

  factory CodexCredentials.fromAuthJson(String source) {
    final root = jsonDecode(source);
    if (root is! Map<String, dynamic> || root['tokens'] is! Map) {
      throw const FormatException('auth.json 缺少 tokens 对象');
    }
    final tokens = Map<String, dynamic>.from(root['tokens'] as Map);
    final access = tokens['access_token']?.toString();
    final refresh = tokens['refresh_token']?.toString();
    final account = tokens['account_id']?.toString();
    if ([access, refresh, account].any((v) => v == null || v.isEmpty)) {
      throw const FormatException(
        'auth.json 缺少 access_token、refresh_token 或 account_id',
      );
    }
    return CodexCredentials(
      accessToken: access!,
      refreshToken: refresh!,
      accountId: account!,
      lastRefresh: DateTime.tryParse('${root['last_refresh'] ?? ''}')?.toUtc(),
    );
  }
}

class RateWindow {
  const RateWindow({
    this.usedPercent,
    this.durationSeconds,
    this.resetAfterSeconds,
    this.resetAt,
  });
  final double? usedPercent;
  final int? durationSeconds;
  final int? resetAfterSeconds;
  final DateTime? resetAt;
  bool get hasDisplayData =>
      usedPercent != null ||
      durationSeconds != null ||
      resetAfterSeconds != null ||
      resetAt != null;
  double? get remainingPercent => usedPercent == null
      ? null
      : (100 - usedPercent!).clamp(0, 100).toDouble();

  /// The portion of this rate-limit window that has not elapsed yet.
  /// It is intentionally separate from [remainingPercent]: time left and
  /// quota left are different signals for a monitoring display.
  double? timeRemainingPercent(DateTime now) {
    if (durationSeconds == null || durationSeconds! <= 0 || resetAt == null) {
      return null;
    }
    final remaining = resetAt!.toLocal().difference(now).inMilliseconds;
    final total = Duration(seconds: durationSeconds!).inMilliseconds;
    return (remaining / total * 100).clamp(0, 100).toDouble();
  }

  factory RateWindow.fromJson(dynamic json) {
    final map = json is Map
        ? Map<String, dynamic>.from(json)
        : const <String, dynamic>{};
    final epoch = integer(map['reset_at']);
    return RateWindow(
      usedPercent: number(map['used_percent']),
      durationSeconds: integer(map['limit_window_seconds']),
      resetAfterSeconds: integer(map['reset_after_seconds']),
      resetAt: epoch == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true),
    );
  }
}

class CodexRateLimit {
  const CodexRateLimit({
    this.allowed,
    this.limitReached,
    this.primary,
    this.secondary,
  });
  final bool? allowed;
  final bool? limitReached;
  final RateWindow? primary;
  final RateWindow? secondary;
  List<RateWindow> get windows =>
      [?primary, ?secondary].where((window) => window.hasDisplayData).toList()
        ..sort(
          (a, b) => (a.durationSeconds ?? 1 << 30).compareTo(
            b.durationSeconds ?? 1 << 30,
          ),
        );
  factory CodexRateLimit.fromJson(dynamic json) {
    final map = json is Map
        ? Map<String, dynamic>.from(json)
        : const <String, dynamic>{};
    return CodexRateLimit(
      allowed: map['allowed'] as bool?,
      limitReached: map['limit_reached'] as bool?,
      primary: map.containsKey('primary_window')
          ? RateWindow.fromJson(map['primary_window'])
          : null,
      secondary: map.containsKey('secondary_window')
          ? RateWindow.fromJson(map['secondary_window'])
          : null,
    );
  }
}

class AdditionalLimit {
  const AdditionalLimit({this.name, this.feature, required this.rateLimit});
  final String? name;
  final String? feature;
  final CodexRateLimit rateLimit;
  String get displayName => name == 'GPT-5.3-Codex-Spark'
      ? 'Codex Spark'
      : (name?.replaceAll(RegExp(r'^GPT-[^ ]+-'), '') ?? feature ?? '附加额度');
  factory AdditionalLimit.fromJson(dynamic json) {
    final map = json is Map
        ? Map<String, dynamic>.from(json)
        : const <String, dynamic>{};
    return AdditionalLimit(
      name: map['limit_name']?.toString(),
      feature: map['metered_feature']?.toString(),
      rateLimit: CodexRateLimit.fromJson(map['rate_limit']),
    );
  }
}

class CodexCredits {
  const CodexCredits({this.hasCredits, this.unlimited, this.balance});
  final bool? hasCredits;
  final bool? unlimited;
  final String? balance;
  factory CodexCredits.fromJson(dynamic json) {
    final map = json is Map
        ? Map<String, dynamic>.from(json)
        : const <String, dynamic>{};
    return CodexCredits(
      hasCredits: map['has_credits'] as bool?,
      unlimited: map['unlimited'] as bool?,
      balance: map['balance']?.toString(),
    );
  }
}

class CodexUsageResponse {
  const CodexUsageResponse({
    this.planType,
    required this.rateLimit,
    required this.additional,
    this.credits,
    this.resetCredits,
  });
  final String? planType;
  final CodexRateLimit rateLimit;
  final List<AdditionalLimit> additional;
  final CodexCredits? credits;
  final int? resetCredits;
  factory CodexUsageResponse.fromJson(dynamic json) {
    final map = json is Map
        ? Map<String, dynamic>.from(json)
        : const <String, dynamic>{};
    final extra = map['additional_rate_limits'];
    final reset = map['rate_limit_reset_credits'];
    return CodexUsageResponse(
      planType: map['plan_type']?.toString(),
      rateLimit: CodexRateLimit.fromJson(map['rate_limit']),
      additional: extra is List
          ? extra.map(AdditionalLimit.fromJson).toList()
          : const [],
      credits: map.containsKey('credits')
          ? CodexCredits.fromJson(map['credits'])
          : null,
      resetCredits: reset is Map ? integer(reset['available_count']) : null,
    );
  }
}

String windowLabel(int? seconds) {
  if (seconds == null) return '--';
  if (seconds % 86400 == 0) return '${seconds ~/ 86400}天';
  if (seconds % 3600 == 0) return '${seconds ~/ 3600}小时';
  if (seconds % 60 == 0) return '${seconds ~/ 60}分钟';
  return '$seconds秒';
}

String durationClock(Duration d) {
  if (d.isNegative) return '等待刷新';
  final hours = d.inHours;
  return '${hours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

String uptimeLabel(Duration d) =>
    '${d.inDays}天 ${(d.inHours % 24).toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
