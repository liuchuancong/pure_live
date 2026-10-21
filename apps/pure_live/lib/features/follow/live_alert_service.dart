import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/app/app_providers.dart' show followRepositoryProvider, sitesProvider;
import 'package:pure_live/features/follow/follow_refresher.dart';
import 'package:pure_live/features/follow/live_alert_rules.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart' show appPreferencesProvider;
import 'package:pure_live/system/configuration/app_preferences_providers.dart' show feedRefreshProvider;

/// The service that keeps the followed rooms' state fresh while the app is up,
/// and reports the rooms that started broadcasting.
///
/// One pass writes every fresh detail back through [followRepositoryProvider],
/// so the follow list, the history cards and the room itself all read the same
/// answered state. A room that started since the previous pass is published on
/// [started]; the shell turns those into the notices the user asked for when it
/// set an interval at all.
final class LiveAlertService {
  /// The service over [ref].
  new(this.ref);

  /// The container the pass reads its parts from.
  final Ref ref;

  Timer? _timer;
  Future<FollowRefreshResult>? _pass;
  final StreamController<LiveRoom> _started = StreamController<LiveRoom>.broadcast();

  /// The rooms that came live since the previous pass.
  Stream<LiveRoom> get started => _started.stream;

  /// Applies the stored interval: null (提醒关着) stops the clock, a value
  /// restarts it. Called at boot and on every preference change.
  void applyInterval() {
    final interval = ref.read(feedRefreshProvider).interval;
    _timer?.cancel();
    if (interval == null) {
      return;
    }
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  /// Runs one pass now. Concurrent calls join the pass in flight rather than
  /// starting a second round of requests for the same rooms.
  Future<FollowRefreshResult> refresh() {
    final running = _pass;
    if (running != null) {
      return running;
    }
    final pass = _run();
    _pass = pass;
    return pass.whenComplete(() => _pass = null);
  }

  Future<FollowRefreshResult> _run() async {
    final repository = ref.read(followRepositoryProvider);
    final result = await FollowRefresher(sites: ref.read(sitesProvider))
        .refresh(repository.rooms, concurrency: ref.read(appPreferencesProvider).refreshConcurrency);
    for (final room in result.rooms) {
      await repository.replaceRoom(room);
    }
    // 开播提醒 covers the viewer's chosen tags (none = every follow): a room
    // that came live without one of them is refreshed but stays quiet.
    final covered = ref.read(appPreferencesProvider).liveAlertTagIds;
    final tagsByRoom = {
      for (final record in repository.rooms) '${record.room.ref.platform}:${record.room.ref.roomId}': record.groupIds,
    };
    for (final room in result.wentLive) {
      final groups = tagsByRoom['${room.ref.platform}:${room.ref.roomId}'] ?? const <String>[];
      if (_started.isClosed || !alertCoversRoom(covered, groups)) {
        continue;
      }
      _started.add(room);
    }
    return result;
  }

  /// Stops the clock and closes [started].
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _started.close();
  }
}

/// The app's live-alert service; the shell owns its lifetime.
// riverpod's provider type (ProviderFamily/...autoDispose) is not exported
// by flutter_riverpod, so the variable annotation the lint asks for cannot
// be written.
// ignore: specify_nonobvious_property_types
final liveAlertServiceProvider = Provider.autoDispose<LiveAlertService>((ref) {
  final service = LiveAlertService(ref)..applyInterval();
  ref
    ..listen(feedRefreshProvider, (_, _) => service.applyInterval())
    ..onDispose(() => unawaited(service.dispose()));
  return service;
});

/// The rooms that came live, for whoever owns the notices. Watching this provider
/// is what keeps the service alive, so the shell listens to it while it is up.
final liveAlertsProvider = StreamProvider<LiveRoom>((ref) => ref.watch(liveAlertServiceProvider).started);
