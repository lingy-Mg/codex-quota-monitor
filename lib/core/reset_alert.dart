class ResetAnnouncement {
  const ResetAnnouncement({
    required this.id,
    required this.resetType,
    required this.announcedAt,
    required this.text,
    required this.sourceUrl,
    required this.trackerName,
    required this.trackerUrl,
    this.scheduledFor,
  });

  final String id;
  final String resetType;
  final DateTime announcedAt;
  final DateTime? scheduledFor;
  final String text;
  final String sourceUrl;
  final String trackerName;
  final String trackerUrl;

  String get signalKey => sourceUrl.isEmpty ? '$trackerName:$id' : sourceUrl;

  factory ResetAnnouncement.fromJson(
    Map<String, dynamic> json, {
    String defaultTrackerName = 'Codex Resets',
    String defaultTrackerUrl = 'https://codex-resets.com',
  }) {
    final id = json['id']?.toString() ?? '';
    final resetType = json['reset_type']?.toString() ?? '';
    final announcedAt = DateTime.tryParse(
      json['announced_at']?.toString() ?? '',
    );
    final source = json['source'];
    if (id.isEmpty || resetType.isEmpty || announcedAt == null) {
      throw const FormatException('Invalid reset announcement');
    }
    return ResetAnnouncement(
      id: id,
      resetType: resetType,
      announcedAt: announcedAt.toUtc(),
      scheduledFor: DateTime.tryParse(
        json['scheduled_for']?.toString() ?? '',
      )?.toUtc(),
      text: json['text']?.toString() ?? '',
      sourceUrl: source is Map ? source['url']?.toString() ?? '' : '',
      trackerName: json['tracker_name']?.toString().isNotEmpty == true
          ? json['tracker_name'].toString()
          : defaultTrackerName,
      trackerUrl: json['tracker_url']?.toString().isNotEmpty == true
          ? json['tracker_url'].toString()
          : defaultTrackerUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reset_type': resetType,
    'announced_at': announcedAt.toIso8601String(),
    'scheduled_for': scheduledFor?.toIso8601String(),
    'text': text,
    'source': {'url': sourceUrl},
    'tracker_name': trackerName,
    'tracker_url': trackerUrl,
  };
}

enum ResetAlertPresentation { dialog, watermark, hidden }

class ResetAlertState {
  const ResetAlertState({
    this.announcements = const [],
    this.presentation = ResetAlertPresentation.hidden,
  });

  final List<ResetAnnouncement> announcements;
  final ResetAlertPresentation presentation;

  ResetAnnouncement? get announcement =>
      announcements.isEmpty ? null : announcements.first;

  bool get isVisible =>
      announcements.isNotEmpty && presentation != ResetAlertPresentation.hidden;

  ResetAlertState copyWith({
    List<ResetAnnouncement>? announcements,
    ResetAlertPresentation? presentation,
  }) => ResetAlertState(
    announcements: announcements ?? this.announcements,
    presentation: presentation ?? this.presentation,
  );
}
