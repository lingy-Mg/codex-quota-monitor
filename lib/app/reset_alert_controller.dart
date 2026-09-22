import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/reset_alert.dart';
import '../services/better_opc_reset_service.dart';
import '../services/reset_alert_api_service.dart';

final resetAlertClientsProvider = Provider<List<ResetAlertClient>>((ref) {
  final clients = <ResetAlertClient>[
    ResetAlertApiService(),
    BetterOpcResetService(),
  ];
  ref.onDispose(() {
    for (final client in clients) {
      client.close(force: true);
    }
  });
  return clients;
});

final resetAlertStoreProvider = Provider<ResetAlertStore>(
  (_) => const ResetAlertStore(),
);

final resetAlertPollIntervalProvider = Provider<Duration>(
  (_) => const Duration(minutes: 5),
);

final resetAlertAutoRefreshProvider = Provider<bool>((_) => true);

final resetAlertProvider =
    AsyncNotifierProvider<ResetAlertController, ResetAlertState>(
      ResetAlertController.new,
    );

class ResetAlertStore {
  const ResetAlertStore();

  static const _key = 'codexResetAlertStateV1';

  Future<ResetAlertState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const ResetAlertState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ResetAlertState();
      final rawAnnouncements = decoded['announcements'];
      final presentationName = decoded['presentation']?.toString();
      final announcements = <ResetAnnouncement>[];
      if (rawAnnouncements is List) {
        for (final item in rawAnnouncements.whereType<Map>()) {
          announcements.add(
            ResetAnnouncement.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      } else {
        // Migrate the single-source state written by version 1.
        final alert = decoded['announcement'];
        if (alert is Map) {
          announcements.add(
            ResetAnnouncement.fromJson(Map<String, dynamic>.from(alert)),
          );
        }
      }
      if (announcements.isEmpty) return const ResetAlertState();
      return ResetAlertState(
        announcements: announcements,
        presentation: ResetAlertPresentation.values.firstWhere(
          (value) => value.name == presentationName,
          orElse: () => ResetAlertPresentation.dialog,
        ),
      );
    } on FormatException {
      await preferences.remove(_key);
      return const ResetAlertState();
    }
  }

  Future<void> save(ResetAlertState value) async {
    if (value.announcements.isEmpty) {
      await clear();
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode({
        'announcements': value.announcements
            .map((announcement) => announcement.toJson())
            .toList(growable: false),
        'presentation': value.presentation.name,
      }),
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}

class ResetAlertController extends AsyncNotifier<ResetAlertState> {
  Timer? _poller;
  bool _busy = false;
  final Map<String, String> _etags = {};

  List<ResetAlertClient> get _clients => ref.read(resetAlertClientsProvider);
  ResetAlertStore get _store => ref.read(resetAlertStoreProvider);

  @override
  Future<ResetAlertState> build() async {
    final cached = await _store.load();
    ref.onDispose(() => _poller?.cancel());
    if (ref.read(resetAlertAutoRefreshProvider)) {
      Timer.run(() => unawaited(refresh()));
    }
    return cached;
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    _poller?.cancel();
    var nextDelay = ref.read(resetAlertPollIntervalProvider);
    final current = state.value ?? const ResetAlertState();
    var announcements = List<ResetAnnouncement>.of(current.announcements);
    var changed = false;
    try {
      for (final client in _clients) {
        try {
          final result = await client.fetch(etag: _etags[client.sourceName]);
          final resultEtag = result.etag;
          if (resultEtag != null) _etags[client.sourceName] = resultEtag;
          if (result.notModified) continue;

          announcements.removeWhere(
            (announcement) => announcement.trackerName == client.sourceName,
          );
          if (result.announcement != null) {
            announcements.add(result.announcement!);
          }
          changed = true;
        } on ResetAlertApiException catch (error) {
          if (error.statusCode == 429 && error.retryAfter != null) {
            if (error.retryAfter! < nextDelay) nextDelay = error.retryAfter!;
          }
        } on FormatException {
          // A malformed source must not erase its last durable alert.
        } catch (_) {
          // One failed source must not hide a signal from the other source.
        }
      }
      if (!changed) return;
      announcements.sort(
        (a, b) => (a.scheduledFor ?? a.announcedAt).compareTo(
          b.scheduledFor ?? b.announcedAt,
        ),
      );
      // Fetches can finish after the user collapses, reopens, or force-dismisses
      // the alert. Merge against the latest presentation so a stale request
      // never reverses that explicit action.
      final latest = state.value ?? current;
      final currentKeys = latest.announcements
          .map((announcement) => announcement.signalKey)
          .toSet();
      final incomingKeys = announcements
          .map((announcement) => announcement.signalKey)
          .toSet();
      final hasNewSignal = incomingKeys.difference(currentKeys).isNotEmpty;
      final next = ResetAlertState(
        announcements: announcements,
        presentation: announcements.isEmpty
            ? ResetAlertPresentation.hidden
            : (hasNewSignal
                  ? ResetAlertPresentation.dialog
                  : latest.presentation),
      );
      if (announcements.isEmpty) {
        await _store.clear();
      } else {
        await _store.save(next);
      }
      state = AsyncData(next);
    } catch (_) {
      // Network failures are retried without exposing request details.
    } finally {
      _busy = false;
      _schedule(nextDelay);
    }
  }

  Future<void> collapseToWatermark() async {
    await _setPresentation(ResetAlertPresentation.watermark);
  }

  Future<void> showDialog() async {
    await _setPresentation(ResetAlertPresentation.dialog);
  }

  Future<void> forceDismiss() async {
    await _setPresentation(ResetAlertPresentation.hidden);
  }

  Future<void> _setPresentation(ResetAlertPresentation presentation) async {
    final current = state.value;
    if (current == null || current.announcements.isEmpty) return;
    final next = current.copyWith(presentation: presentation);
    await _store.save(next);
    state = AsyncData(next);
  }

  void _schedule(Duration delay) {
    _poller?.cancel();
    if (!ref.read(resetAlertAutoRefreshProvider)) return;
    _poller = Timer(delay, () => unawaited(refresh()));
  }
}
