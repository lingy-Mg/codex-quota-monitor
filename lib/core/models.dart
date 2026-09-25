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
    this.resetCards,
  });
  final String? planType;
  final CodexRateLimit rateLimit;
  final List<AdditionalLimit> additional;
  final CodexCredits? credits;
  final int? resetCredits;

  /// Null means the detail endpoint was unavailable; an empty list is known empty.
  final List<ResetCredit>? resetCards;
  factory CodexUsageResponse.fromJson(dynamic json, {dynamic resetDetails}) {
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
          : extra is Map
          ? (extra.containsKey('rate_limit')
                ? [AdditionalLimit.fromJson(extra)]
                : extra.entries.where((e) => e.value is Map).map((e) {
                    final item = Map<String, dynamic>.from(e.value as Map);
                    item.putIfAbsent('limit_name', () => e.key.toString());
                    return AdditionalLimit.fromJson(item);
                  }).toList())
          : const [],
      credits: map.containsKey('credits')
          ? CodexCredits.fromJson(map['credits'])
          : null,
      resetCredits: resetDetails is Map
          ? integer(resetDetails['available_count']) ??
                (reset is Map ? integer(reset['available_count']) : null)
          : reset is Map
          ? integer(reset['available_count'])
          : null,
      resetCards: resetDetails is Map && resetDetails['credits'] is List
          ? (resetDetails['credits'] as List)
                .whereType<Map>()
                .map(ResetCredit.fromJson)
                .where((card) => card.status == 'available')
                .toList()
          : null,
    );
  }
}

class ResetCredit {
  const ResetCredit({this.expiresAt, this.status, this.supportedByPlan});

  final DateTime? expiresAt;
  final String? status;
  final bool? supportedByPlan;

  factory ResetCredit.fromJson(Map json) => ResetCredit(
    expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}')?.toUtc(),
    status: json['status']?.toString(),
    supportedByPlan: json['is_supported_by_plan'] as bool?,
  );

  String expiryLabel(DateTime now) {
    if (expiresAt == null) return '到期时间未知';
    final remaining = expiresAt!.difference(now);
    if (remaining <= Duration.zero) return '已到期';
    if (remaining.inDays == 0) return '不足1天';
    return '${remaining.inDays}天';
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
  final days = d.inDays > 0 ? '${d.inDays}天 ' : '';
  final hours = d.inHours % 24;
  return '$days${hours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

String uptimeLabel(Duration d) =>
    '${d.inDays}天 ${(d.inHours % 24).toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
