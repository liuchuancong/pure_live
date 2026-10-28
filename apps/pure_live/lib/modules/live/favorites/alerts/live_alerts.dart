import 'dart:async' show Timer, unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/favorites/alerts/live_alert_events.dart' show LiveAlertObserver, liveAlertObserver;
import 'package:pure_live/features/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/favorites/data/follow_tags.dart' show FollowTag, followTagsProvider;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// Tells which rooms began a broadcast, once per broadcast.
///
/// The first state seen of a room is only remembered: the app's start, a new
/// follow or a just-enabled switch is not news. A room is new on air when it
/// is live now and was last seen off air — unless it is the same broadcast
/// (the start time within [sameStartTolerance], or back within
/// [reconnectWindow] of going off) — or its start time moved on while it was
/// live. A failed request is no evidence and changes nothing.
final class LiveAlertTracker {
  /// Creates the tracker; [now] is the clock (tests).
  LiveAlertTracker({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// A room back on air this soon after going off is the same broadcast
  /// reconnecting.
  static const Duration reconnectWindow = Duration(minutes: 15);

  /// Start times this close are the same broadcast (platforms round them).
  static const Duration sameStartTolerance = Duration(minutes: 2);

  final DateTime Function() _now;
  final Map<String, _Seen> _seen = {};

  /// Takes the states of [rooms]; returns those that began a broadcast
  /// (none when [quiet]).
  List<LiveRoom> observe(Iterable<LiveRoom> rooms, {bool quiet = false}) {
    final now = _now();
    final started = <LiveRoom>[];
    for (final room in rooms) {
      final status = room.broadcast.effectiveLiveStatus;
      if (status == LiveStatus.unknown) continue;
      final live = status == LiveStatus.live;
      final key = room.ref.identityKey;
      final seen = _seen[key];
      if (seen == null) {
        _seen[key] = _Seen(live: live, startedAt: live ? room.broadcast.startedAt : null);
        continue;
      }
      if (!live) {
        if (seen.live) {
          seen
            ..live = false
            ..endedAt = now;
        }
        continue;
      }
      final isNew = seen.live ? _restarted(seen.startedAt, room.broadcast.startedAt) : !_sameBroadcast(seen, room, now);
      seen.live = true;
      if (isNew) {
        seen
          ..startedAt = room.broadcast.startedAt
          ..endedAt = null;
        if (!quiet) started.add(room);
      } else {
        seen.startedAt ??= room.broadcast.startedAt;
      }
    }
    return started;
  }

  /// Forgets every room (the switch turned off: turning it on starts over).
  void forget() => _seen.clear();

  bool _sameBroadcast(_Seen seen, LiveRoom room, DateTime now) {
    final before = seen.startedAt;
    final start = room.broadcast.startedAt;
    if (before != null && start != null && start.difference(before).abs() <= sameStartTolerance) return true;
    final ended = seen.endedAt;
    return ended != null && now.difference(ended) < reconnectWindow;
  }

  static bool _restarted(DateTime? before, DateTime? now) =>
      before != null && now != null && now.difference(before) > reconnectWindow;
}

final class _Seen {
  _Seen({required this.live, this.startedAt});

  bool live;
  DateTime? startedAt;
  DateTime? endedAt;
}

/// The follows "开播提醒" covers: every follow, or with tags chosen those
/// carrying one of them. A chosen tag that no longer exists does not count;
/// with none left it is every follow again (what the settings show too).
List<LiveRoom> liveAlertRooms(List<LiveRoom> follows, {required List<String> chosen, required List<FollowTag> tags}) {
  final existing = {for (final tag in tags) tag.id};
  final wanted = {
    for (final id in chosen)
      if (existing.contains(id)) id,
  };
  if (wanted.isEmpty) return follows;
  return [
    for (final room in follows)
      if (room.local.tagIds.any(wanted.contains)) room,
  ];
}

/// Runs the live alerts in the primary window while the app is open: checks
/// the covered follows at start and every [kLiveAlertCheckInterval], on
/// resume, and once when the follows first open. A check merges what it
/// fetched into the follows store, so the favorites page shares the fresh
/// states; only broadcasts that began since the last check notify.
final class LiveAlertWatcher extends ConsumerStatefulWidget {
  /// Watches while [child] is mounted.
  const LiveAlertWatcher({required this.child, super.key});

  /// The app below the watcher.
  final Widget child;

  @override
  ConsumerState<LiveAlertWatcher> createState() => _LiveAlertWatcherState();
}

final class _LiveAlertWatcherState extends ConsumerState<LiveAlertWatcher> with WidgetsBindingObserver {
  final LiveAlertTracker _tracker = LiveAlertTracker();
  Timer? _timer;
  bool _seeded = false;
  bool _checking = false;
  late final LiveAlertTapHandler _tapHandler = _openAlertedRoom;
  late final LiveAlertObserver _refreshObserver = _observeRefresh;

  bool get _primary => ref.read(isPrimaryWindowProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    liveAlertTapHandler = _tapHandler;
    liveAlertObserver = _refreshObserver;
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (liveAlertTapHandler == _tapHandler) liveAlertTapHandler = null;
    if (identical(liveAlertObserver, _refreshObserver)) liveAlertObserver = null;
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _arm(checkNow: _seeded);
  }

  void _arm({bool checkNow = false}) {
    if (!mounted || !_primary) return;
    final settings = ref.read(liveAlertSettingsProvider);
    if (!settings.enabled) {
      _timer?.cancel();
      _timer = null;
      _seeded = false;
      _tracker.forget();
      return;
    }
    unawaited(requestUserNotificationPermission());
    _timer ??= Timer.periodic(kLiveAlertCheckInterval, (_) => unawaited(_check(quiet: false)));
    if (!_seeded || checkNow) unawaited(_check(quiet: !_seeded));
  }

  Future<void> _check({required bool quiet}) async {
    if (!mounted || _checking || !_primary) return;
    final settings = ref.read(liveAlertSettingsProvider);
    if (!settings.enabled) return;
    final follows = ref.read(followsProvider);
    if (!follows.ready || follows.rooms.isEmpty) return;
    final covered = liveAlertRooms(
      follows.rooms,
      chosen: settings.tagIds,
      tags: ref.read(followTagsProvider),
    );
    if (covered.isEmpty) {
      _seeded = true;
      return;
    }
    _checking = true;
    try {
      final fresh = await ref.read(followsProvider.notifier).fetchLiveStates(covered);
      if (!mounted || !ref.read(liveAlertSettingsProvider).enabled) return;
      final started = _tracker.observe(fresh, quiet: quiet || !_seeded);
      _seeded = true;
      if (quiet) return;
      final keys = {for (final room in covered) room.ref.identityKey};
      for (final room in started) {
        if (!keys.contains(room.ref.identityKey)) continue;
        await _post(room);
      }
    } finally {
      _checking = false;
    }
  }

  /// One follows refresh pass's fresh rooms, from the favorites page's
  /// manual or automatic refresh: the same tracker as the timer, so a
  /// broadcast the pass caught is not announced again by the next check.
  void _observeRefresh(List<LiveRoom> rooms, {required bool quiet}) {
    if (!mounted || !_primary) return;
    final settings = ref.read(liveAlertSettingsProvider);
    if (!settings.enabled) {
      _tracker.forget();
      return;
    }
    final started = _tracker.observe(rooms, quiet: quiet || !_seeded);
    _seeded = true;
    if (quiet || started.isEmpty) return;
    final covered = liveAlertRooms(rooms, chosen: settings.tagIds, tags: ref.read(followTagsProvider));
    final keys = {for (final room in covered) room.ref.identityKey};
    for (final room in started) {
      if (keys.contains(room.ref.identityKey)) unawaited(_post(room));
    }
  }

  Future<void> _post(LiveRoom room) async {    if (!mounted) return;
    final t = context.t;
    final site = ref.read(sitesProvider).getById(room.ref.platform);
    final platform = site == null ? room.ref.platform : localizedSiteName(site);
    final title = room.content.title.trim();
    await postLiveAlert(
      identityKey: room.ref.identityKey,
      title: title.isEmpty
          ? t.settings.liveAlertFallbackTitle(platform: platform, roomId: room.ref.roomId)
          : title,
      body: t.settings.liveAlertNotificationBody(platform: platform),
    );
  }

  void _openAlertedRoom(String identityKey) {
    final split = identityKey.indexOf(':');
    if (split <= 0 || split == identityKey.length - 1) return;
    unawaited(
      ref.read(appRouterProvider).push(
        RoomRoute(platform: identityKey.substring(0, split), roomId: identityKey.substring(split + 1)).location,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveAlertSettingsProvider, (previous, next) {
      if (previous?.enabled != next.enabled) {
        _arm();
        return;
      }
      if (previous?.tagIds.join('\u0000') != next.tagIds.join('\u0000')) unawaited(_check(quiet: true));
    });
    ref.listen(followsProvider.select((follows) => follows.ready), (previous, next) {
      if (next) _arm(checkNow: _seeded);
    });
    return widget.child;
  }
}
