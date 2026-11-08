import 'dart:async';

import 'package:live_sites/live_sites.dart'
    show
        LiveRoom,
        LiveRoomIdentity,
        LiveRoomRefIdentity,
        LiveSiteAuthenticationError,
        LiveSiteContentUnavailable,
        LiveSiteError,
        LiveSiteNotFound;
import 'package:media_core/media_core.dart' show PlayerCoreState, PlayerFailure;

/// Room reservations shared by every scheduler of one surface: the wall's
/// panes pass one group in, so two cells never resolve into the same room;
/// a room page running alone owns a private one.
final class AutoRoomSwitchGroup {
  final Map<Object, String> _rooms = {};

  /// Whether another member already holds [room].
  bool available(Object owner, LiveRoom room) =>
      !_rooms.entries.any((entry) => entry.key != owner && entry.value == room.identityKey);

  /// Claims a room synchronously, before another asynchronous lookup finishes.
  void claim(Object owner, LiveRoom room) => _rooms[owner] = room.identityKey;

  /// Releases a removed surface.
  void release(Object owner) => _rooms.remove(owner);
}

/// Whether [error] is the platform's own word that this room cannot be
/// watched, the only site failures worth an automatic switch.
///
/// The sealed failure separates what the platform said from what happened on
/// the way to it: a room that does not exist any more ([LiveSiteNotFound],
/// a broadcast that ended) and content the platform refuses to serve
/// ([LiveSiteContentUnavailable]) are verdicts about the room. A login the
/// viewer can renew ([LiveSiteAuthenticationError] with `cookieSuspect`) is a
/// verdict about the account — the room page already raises its standing
/// notice for that one, and bouncing the viewer to another room would fight
/// it. The transport failures (`LiveSiteNetworkError`, a rate limit) are
/// transient and keep their own retries, and a parse or unsupported answer is
/// this app's problem, not the room's.
bool liveSiteErrorWarrantsSwitch(LiveSiteError error) => switch (error) {
  LiveSiteNotFound() => true,
  LiveSiteContentUnavailable() => true,
  LiveSiteAuthenticationError(:final cookieSuspect) => !cookieSuspect,
  _ => false,
};

/// The factory every scheduler timer comes from; tests hand in one that
/// records the waits and fires the callbacks by hand.
typedef AutoRoomSwitchTimerFactory = Timer Function(Duration duration, void Function() callback);

/// Opt-in, bounded switching through freshly confirmed online follows.
///
/// The room's own recovery always runs first: a network blink keeps probing
/// in the playback session and never reaches this scheduler (a network-kind
/// [PlayerFailure] is refused below), and so do a paused room and a viewer
/// choice still being applied. What remains is the platform's own verdict —
/// a detail that says the broadcast is over, [liveSiteErrorWarrantsSwitch]
/// on the site error that failed the open, or a player error the engine
/// could not recover from.
///
/// A triggered round first re-reads the current room (its 20-second grace
/// twice), then walks the follows from the room after the current one: a
/// candidate must come back live, unrestricted and still followed before it
/// replaces this room. A candidate is tried once per round; when playback
/// stays healthy for 30 seconds the round forgets its attempts, so a streamer
/// who went offline for a moment is watched again the next time. No polling
/// starts after the candidate list is exhausted.
final class AutoRoomSwitch {
  /// Creates a scheduler for one room page or one multi-view pane.
  AutoRoomSwitch({
    required this.enabled,
    required this.followsOf,
    required this.isFollowed,
    required this.lookupRoom,
    required this.onSwitch,
    required this.maySwitch,
    this.onRefresh,
    this.onExhausted,
    AutoRoomSwitchGroup? group,
    this.lookupTimeout = const Duration(seconds: 10),
    this.timer = Timer.new,
  }) : _group = group ?? AutoRoomSwitchGroup();

  /// Whether the viewer turned the switching on (the settings switch).
  final bool Function() enabled;

  /// The followed rooms, in storage order.
  final List<LiveRoom> Function() followsOf;

  /// Whether `candidate` is still followed right now; a list read from a
  /// moment ago is not enough, an unfollowed room must not be opened.
  final bool Function(LiveRoom candidate) isFollowed;

  /// Reads the platform's current detail for `candidate`; null (or a throw
  /// other than [TimeoutException]) means this candidate failed and the next
  /// one may be tried. The scheduler applies [lookupTimeout] itself.
  final Future<LiveRoom?> Function(LiveRoom candidate) lookupRoom;

  /// Replaces this room without changing the surrounding layout or audio.
  final void Function(LiveRoom room) onSwitch;

  /// The owning surface's own conditions: the page is on screen, the wall is
  /// active, the session still exists.
  final bool Function() maySwitch;

  /// Re-reads the current room before replacing it after the open failed.
  final Future<void> Function()? onRefresh;

  /// Called once when this round has no usable candidate.
  final void Function()? onExhausted;

  /// Maximum time for one platform lookup.
  final Duration lookupTimeout;

  /// The factory every scheduler timer comes from; tests hand in one that
  /// records the waits and fires the callbacks by hand.
  final AutoRoomSwitchTimerFactory timer;

  final AutoRoomSwitchGroup _group;
  final Object _owner = Object();
  final Set<String> _attempted = {};
  String? _checking;
  Timer? _pending;
  Timer? _healthy;
  Timer? _retryDelay;
  int _refreshes = 0;
  LiveRoom? _room;
  PlayerCoreState _playback = PlayerCoreState.idle;
  PlayerFailure? _failure;
  bool _resolving = false;
  bool _unavailable = false;
  bool _replay = false;
  bool _held = false;
  bool _exhausted = false;
  bool _searching = false;
  bool _disposed = false;
  int _epoch = 0;

  /// A round stopped after trying every available online follow.
  bool get exhausted => _exhausted;

  /// Binds a new room; an explicit user choice starts a fresh round, an
  /// automatic switch keeps the attempts already spent.
  void setRoom(LiveRoom room, {bool automatic = false}) {
    if (!automatic || _room?.ref.identityKey != room.ref.identityKey) _resetConfirmations();
    _cancel();
    _healthy?.cancel();
    _healthy = null;
    _room = room;
    _playback = PlayerCoreState.idle;
    _failure = null;
    _resolving = true;
    _unavailable = false;
    _replay = false;
    _held = false;
    if (!automatic) {
      _attempted.clear();
      _exhausted = false;
    }
    _group.claim(_owner, room);
  }

  /// Supplies actual controller and player state, never inferred UI text.
  void update({
    required LiveRoom room,
    required PlayerCoreState playback,
    required bool resolving,
    required bool unavailable,
    bool replay = false,
    PlayerFailure? failure,
  }) {
    if (_disposed) return;
    _room = room;
    _group.claim(_owner, room);
    _playback = playback;
    _failure = failure;
    _resolving = resolving;
    _unavailable = unavailable;
    _replay = replay;
    if (playback.paused ||
        (playback.stopped && !resolving && !unavailable && !room.broadcast.isExplicitlyOfflineNow)) {
      // A stopped room the viewer (or the platform's lifecycle) left on
      // purpose is theirs; only a stop the failure explains counts.
      _held = true;
    } else if (playback.opening || playback.playing || playback.buffering || playback.seeking) {
      _held = false;
    }
    if (enabled() &&
        playback.playing &&
        room.broadcast.isLiveNow &&
        !replay &&
        !unavailable &&
        !playback.hasError) {
      _healthy ??= timer(const Duration(seconds: 30), () {
        _healthy = null;
        _attempted.clear();
        _exhausted = false;
        _refreshes = 0;
      });
    } else {
      _healthy?.cancel();
      _healthy = null;
    }
    _evaluate();
  }

  /// The setting was turned off and on again (or a room switched): the
  /// round's memory starts over, so nothing the old state tried is skipped
  /// or retried because of it.
  void restart() {
    _cancel();
    _resetConfirmations();
    _attempted.clear();
    _exhausted = false;
    _evaluate();
  }

  /// Empties the scheduler and releases its reservation (the room closed).
  void clear() {
    _resetConfirmations();
    _cancel();
    _healthy?.cancel();
    _healthy = null;
    _room = null;
    _attempted.clear();
    _exhausted = false;
    _group.release(_owner);
  }

  bool get _eligible {
    final room = _room;
    if (_disposed || _held || _resolving || _exhausted || room == null) return false;
    if (!enabled() || !maySwitch()) return false;
    if (_replay || room.broadcast.isRecord) return false;
    if (_playback.paused || (_playback.hasError && (_failure?.isNetworkRelated ?? false))) return false;
    return room.broadcast.isExplicitlyOfflineNow || _unavailable || _playback.hasError;
  }

  void _evaluate() {
    if (!_eligible) {
      _cancel();
    } else if (!_searching && _pending == null && _retryDelay == null) {
      // Avoid acting inside the synchronous state notification that fed us.
      _pending = timer(const Duration(seconds: 1), () {
        _pending = null;
        if (!_eligible) return;
        if (onRefresh != null && _refreshes < 2) {
          _refreshCurrent();
        } else {
          unawaited(_next());
        }
      });
    }
  }

  void _cancel() {
    if (_checking case final identity?) _attempted.remove(identity);
    _checking = null;
    _epoch++;
    _pending?.cancel();
    _pending = null;
    _searching = false;
  }

  void _resetConfirmations() {
    _retryDelay?.cancel();
    _retryDelay = null;
    _refreshes = 0;
  }

  void _refreshCurrent() {
    _refreshes++;
    // A full reload may finish before native playback starts. Give it time.
    _retryDelay = timer(const Duration(seconds: 20), () {
      _retryDelay = null;
      _evaluate();
    });
    unawaited(
      Future<void>.sync(onRefresh!).catchError((Object _) {
        // Failed confirmation is not evidence that a broadcast ended.
      }),
    );
  }

  bool _current(int epoch) => epoch == _epoch && _eligible;

  Future<void> _next() async {
    final epoch = ++_epoch;
    _searching = true;
    final current = _room!;
    _attempted.add(current.ref.identityKey);
    try {
      final follows = followsOf();
      final at = follows.indexWhere((room) => room.ref.identityKey == current.ref.identityKey);
      final ordered = at < 0 ? follows : [...follows.skip(at + 1), ...follows.take(at + 1)];
      for (final candidate in ordered) {
        if (!_current(epoch)) return;
        if (!candidate.broadcast.isLiveNow ||
            _attempted.contains(candidate.ref.identityKey) ||
            !_group.available(_owner, candidate)) {
          continue;
        }
        _attempted.add(candidate.ref.identityKey);
        _checking = candidate.ref.identityKey;
        LiveRoom? detail;
        try {
          detail = await lookupRoom(candidate).timeout(lookupTimeout);
        } on TimeoutException {
          if (epoch == _epoch) _checking = null;
          // A slow or lost network must not produce a cascade of room opens.
          break;
        } on Object {
          if (epoch == _epoch) _checking = null;
          continue;
        }
        // A candidate the ask never confirmed is not a room to open: only
        // the platform's fresh detail says the broadcast is still on.
        if (detail == null) {
          if (epoch == _epoch) _checking = null;
          continue;
        }
        if (!_current(epoch)) return;
        // A platform may answer under another id for the same room; the
        // merge (and the claim) must land on the follow's identity, or the
        // card the viewer knows would not be the room that opens.
        final normalized = detail.ref == candidate.ref ? detail : detail.rebuild((b) => b..ref.replace(candidate.ref));
        if (!normalized.broadcast.isLiveNow ||
            normalized.broadcast.isRestricted ||
            !_group.available(_owner, normalized)) {
          _checking = null;
          continue;
        }
        _checking = null;
        if (!isFollowed(candidate) || !_group.available(_owner, normalized)) continue;
        final merged = candidate.mergedWith(normalized);
        _attempted.add(merged.ref.identityKey);
        _group.claim(_owner, merged);
        onSwitch(merged);
        return;
      }
      if (_current(epoch)) {
        _exhausted = true;
        onExhausted?.call();
      }
    } on Object {
      if (_current(epoch)) {
        _exhausted = true;
        onExhausted?.call();
      }
    } finally {
      if (epoch == _epoch) {
        _checking = null;
        _searching = false;
      }
    }
  }

  /// Cancels pending work; late platform answers cannot replace another room.
  void dispose() {
    _disposed = true;
    _cancel();
    _healthy?.cancel();
    _resetConfirmations();
    _group.release(_owner);
  }
}
