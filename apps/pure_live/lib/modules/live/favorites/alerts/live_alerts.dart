import 'dart:async' show Timer, unawaited;
import 'dart:io' show File;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/alerts/live_alert_background.dart' show scheduleLiveAlertCheck;
import 'package:pure_live/modules/live/favorites/alerts/live_alert_events.dart'
    show LiveAlertObserver, liveAlertObserver;
import 'package:pure_live/modules/live/favorites/alerts/live_alert_watch.dart'
    show LiveAlertRoom, LiveAlertTexts, LiveAlertWatch, LiveAlertWatchFile, writeLiveAlertWatch;
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/modules/live/favorites/data/follow_tags.dart' show FollowTag, followTagsProvider;
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
        _seen[key] = _Seen(live: live, startedAt: live ? room.broadcast.startedAt : null, seenAt: now);
        continue;
      }
      seen.seenAt = now;
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

  /// What is known of each room (identity key → state), for the background
  /// check, which carries on from it and hands its own back.
  Map<String, LiveAlertSeen> get states => {
    for (final MapEntry(:key, :value) in _seen.entries)
      key: (live: value.live, startedAt: value.startedAt, endedAt: value.endedAt, seenAt: value.seenAt ?? _now()),
  };

  /// Takes [states] where they are newer than what is known: a broadcast
  /// the background check already told of is not told again here.
  void adopt(Map<String, LiveAlertSeen> states) {
    for (final MapEntry(:key, :value) in states.entries) {
      final known = _seen[key];
      if (known != null && !value.seenAt.isAfter(known.seenAt ?? DateTime.fromMillisecondsSinceEpoch(0))) continue;
      _seen[key] = _Seen(live: value.live, startedAt: value.startedAt, seenAt: value.seenAt)..endedAt = value.endedAt;
    }
  }

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
  _Seen({required this.live, required this.seenAt, this.startedAt});

  bool live;
  DateTime? startedAt;
  DateTime? endedAt;
  DateTime? seenAt;
}

/// One room's last known state, shared with the background check
/// ([LiveAlertTracker.states]).
typedef LiveAlertSeen = ({bool live, DateTime? startedAt, DateTime? endedAt, DateTime seenAt});

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

  /// The scope's container, read through the element once while it is active.
  /// Lifecycle callbacks can run after the element is deactivated, where an
  /// ancestor lookup through [ref] is refused.
  ProviderContainer? _container;
  late Translations _translations;

  bool get _primary => _container?.read(isPrimaryWindowProvider) ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    liveAlertTapHandler = _tapHandler;
    liveAlertObserver = _refreshObserver;
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
    _translations = context.t;
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
    final container = _container;
    if (!mounted || container == null || !_primary) return;
    final settings = container.read(liveAlertSettingsProvider);
    if (!settings.enabled) {
      _timer?.cancel();
      _timer = null;
      _seeded = false;
      _tracker.forget();
      final file = _watchFile();
      if (file != null) unawaited(file.clear());
      unawaited(scheduleLiveAlertCheck(on: false, filePath: ''));
      return;
    }
    unawaited(requestUserNotificationPermission());
    // The background check carries the same schedule the app keeps: the
    // system runs it while the app is frozen or gone.
    final file = _watchFile();
    if (file != null) unawaited(scheduleLiveAlertCheck(on: true, filePath: file.file.path));
    _timer ??= Timer.periodic(kLiveAlertCheckInterval, (_) => unawaited(_check(quiet: false)));
    if (!_seeded || checkNow) unawaited(_check(quiet: !_seeded));
  }

  Future<void> _check({required bool quiet}) async {
    final container = _container;
    if (!mounted || container == null || _checking || !_primary) return;
    final settings = container.read(liveAlertSettingsProvider);
    if (!settings.enabled) return;
    final follows = container.read(followsProvider);
    if (!follows.ready || follows.rooms.isEmpty) return;
    final covered = liveAlertRooms(follows.rooms, chosen: settings.tagIds, tags: container.read(followTagsProvider));
    if (covered.isEmpty) {
      _seeded = true;
      return;
    }
    _checking = true;
    try {
      final fresh = await container.read(followsProvider.notifier).fetchLiveStates(covered);
      if (!mounted || !container.read(liveAlertSettingsProvider).enabled) return;
      final started = _tracker.observe(fresh, quiet: quiet || !_seeded);
      _seeded = true;
      if (quiet) return;
      final keys = {for (final room in covered) room.ref.identityKey};
      for (final room in started) {
        if (!keys.contains(room.ref.identityKey)) continue;
        await _post(room);
      }
      unawaited(_writeWatch(covered: covered));
    } finally {
      _checking = false;
    }
  }

  /// The state file the background check shares, in the app's data area.
  LiveAlertWatchFile? _watchFile() {
    final container = _container;
    if (container == null) return null;
    try {
      return LiveAlertWatchFile(File(p.join(container.read(appPathsProvider).data.path, LiveAlertWatchFile.name)));
    } on Object {
      return null;
    }
  }

  /// The words the notification carries, written with their placeholders so
  /// the background check fills them in the app's language at write time.
  LiveAlertTexts? _texts() {
    try {
      final t = context.t;
      return (
        bodyTemplate: t.settings.liveAlertNotificationBody(platform: '{platform}'),
        fallbackTemplate: t.settings.liveAlertFallbackTitle(platform: '{platform}', roomId: '{roomId}'),
      );
    } on Object {
      return null;
    }
  }

  /// Lays the shared state down: the covered follows, what the tracker has
  /// seen, and the words. The background check skips while this file says
  /// the app is current, and merges what it learns into what is here.
  Future<void> _writeWatch({required List<LiveRoom> covered}) async {
    final file = _watchFile();
    final texts = _texts();
    if (file == null || texts == null) return;
    final sites = _container?.read(sitesProvider);
    final rows = [
      for (final room in covered)
        LiveAlertRoom(
          platform: room.ref.platform,
          roomId: room.ref.roomId,
          name: room.anchor?.name ?? '',
          platformLabel: sites == null
              ? room.ref.platform
              : (sites.getById(room.ref.platform) == null
                    ? room.ref.platform
                    : localizedSiteName(sites.getById(room.ref.platform)!)),
        ),
    ];
    writeLiveAlertWatch(
      file,
      LiveAlertWatch(
        rooms: rows,
        states: _tracker.states,
        texts: texts,
        nextCheck: DateTime.now().add(kLiveAlertCheckInterval),
      ),
    );
  }

  /// One follows refresh pass's fresh rooms, from the favorites page's
  /// manual or automatic refresh: the same tracker as the timer, so a
  /// broadcast the pass caught is not announced again by the next check.
  void _observeRefresh(List<LiveRoom> rooms, {required bool quiet}) {
    final container = _container;
    if (!mounted || container == null || !_primary) return;
    final settings = container.read(liveAlertSettingsProvider);
    if (!settings.enabled) {
      _tracker.forget();
      return;
    }
    final started = _tracker.observe(rooms, quiet: quiet || !_seeded);
    _seeded = true;
    if (quiet || started.isEmpty) return;
    final covered = liveAlertRooms(rooms, chosen: settings.tagIds, tags: container.read(followTagsProvider));
    final keys = {for (final room in covered) room.ref.identityKey};
    for (final room in started) {
      if (keys.contains(room.ref.identityKey)) unawaited(_post(room));
    }
  }

  Future<void> _post(LiveRoom room) async {
    if (!mounted) return;
    final site = _container?.read(sitesProvider).getById(room.ref.platform);
    final platform = site == null ? room.ref.platform : localizedSiteName(site);
    final title = room.content.title.trim();
    await postLiveAlert(
      identityKey: room.ref.identityKey,
      title: title.isEmpty
          ? _translations.settings.liveAlertFallbackTitle(platform: platform, roomId: room.ref.roomId)
          : title,
      body: _translations.settings.liveAlertNotificationBody(platform: platform),
    );
  }

  void _openAlertedRoom(String identityKey) {
    final split = identityKey.indexOf(':');
    if (split <= 0 || split == identityKey.length - 1) return;
    final container = _container;
    if (container == null) return;
    unawaited(
      container
          .read(appRouterProvider)
          .push(
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
