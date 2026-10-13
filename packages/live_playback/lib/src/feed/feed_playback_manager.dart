import 'dart:async';

import 'package:live_playback/src/coordinator/playback_session_coordinator.dart';
import 'package:live_playback/src/model/content_type.dart';
import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/session/playback_session.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:rxdart/rxdart.dart';

/// One item of a vertical feed, already resolved by the host.
///
/// The host owns "what is at index N" — it has the room list, the site and the
/// pagination logic; the manager owns what to do with it (open, keep warm,
/// prune). Keeping the entry a plain value means a feed page can be built from
/// whatever the site returned without the manager knowing about sites.
final class FeedEntry {
  /// Creates a feed entry.
  const new({
    required this.id,
    required this.source,
    this.candidateSources = const <PlayerSource>[],
    this.metadata = PlaybackMetadata.none,
    this.contentType = ContentType.live,
    this.createDanmaku,
  });

  /// The business id (room id, video id). Doubles as the session key.
  final String id;

  /// The resolved playback source.
  final PlayerSource source;

  /// Alternative lines/qualities for recovery.
  final List<PlayerSource> candidateSources;

  /// Room identity for the overlay and the notification.
  final PlaybackMetadata metadata;

  /// Live or recorded.
  final ContentType contentType;

  /// Builds the room's chat controller on demand.
  ///
  /// A factory rather than an instance because a preloaded entry that never
  /// gets watched must not have opened a socket — the controller is created
  /// only when a session actually starts for it.
  final DanmakuController Function()? createDanmaku;
}

/// Resolves the entry at an index, loading more of the list if needed.
typedef FeedEntryProvider = Future<FeedEntry> Function(int index);

/// State of the vertical feed.
final class FeedState {
  /// Creates feed state.
  const new({required this.currentIndex, this.activeSessionId, this.isPreloading = false});

  /// The index on screen, or `-1` before the first scroll.
  final int currentIndex;

  /// The session of the item on screen.
  final String? activeSessionId;

  /// Whether neighbours are being opened right now.
  final bool isPreloading;

  /// Whether an item is on screen.
  bool get isActive => activeSessionId != null;

  /// A copy with fields replaced.
  FeedState copyWith({int? currentIndex, String? activeSessionId, bool? isPreloading}) {
    return FeedState(
      currentIndex: currentIndex ?? this.currentIndex,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      isPreloading: isPreloading ?? this.isPreloading,
    );
  }
}

/// How a feed's items are being watched.
///
/// The same feed serves two pages with different sound rules: a home/list page
/// showing muted previews, and the immersive page where the item on screen is
/// the one you hear. Making it explicit keeps "why is this playing out loud"
/// answerable from one field instead of from a stack of page flags.
enum FeedPlaybackMode {
  /// Tiles: every item is muted and none owns the audio channel.
  preview,

  /// Full-size items: the item on screen is audible and owns the channel.
  immersive,
}

/// TikTok-style vertical playback: one item on screen, neighbours warm.
///
/// The manager exists for two behaviours a naive `PageView` + one player gets
/// wrong:
///
/// - **anchors**: leaving an item remembers where it was (and whether it was
///   playing), so swiping back resumes instead of restarting — the thing that
///   makes a feed feel like a feed rather than a list of tabs;
/// - **preloading**: the next item's session is opened and buffered while the
///   current one plays, so the swipe lands on a picture instead of a spinner.
///
/// Preloaded sessions are muted at every moment: only the item on screen may
/// be heard, which is the same one-audio-channel rule the coordinator enforces
/// for windows — and in [FeedPlaybackMode.preview] even that one is silent.
///
/// A page that leaves while its item is playing can hand it to an overlay
/// (`openDetail` then a hand-off, or [pinSession] directly). A pinned session is
/// never recycled by the scroll window or by [dispose]: the small window owns
/// it from then on, and the page it came from must not take it away.
final class FeedPlaybackManager {
  /// Creates a feed manager.
  new({required this.coordinator, this.preloadCount = 1});

  /// The session registry.
  final PlaybackSessionCoordinator coordinator;

  /// How many neighbours on each side stay warm.
  final int preloadCount;

  final BehaviorSubject<FeedState> _stateSubject = BehaviorSubject<FeedState>.seeded(const FeedState(currentIndex: -1));

  final Map<int, _FeedAnchor> _anchors = <int, _FeedAnchor>{};
  final Map<int, String> _idByIndex = <int, String>{};
  final Set<int> _preloading = <int>{};
  final Set<String> _pinned = <String>{};

  FeedPlaybackMode _mode = FeedPlaybackMode.immersive;

  bool _disposed = false;

  /// Current feed state.
  ValueStream<FeedState> get state => _stateSubject.stream;

  /// How the feed is watching right now.
  FeedPlaybackMode get mode => _mode;

  /// The session ids the feed must not stop: overlays own them now.
  Set<String> get pinnedSessionIds => Set<String>.unmodifiable(_pinned);

  /// Switches the whole feed between muted previews and audible playback.
  ///
  /// Applied to the item on screen immediately, so the button that toggles it
  /// does not have to also find the session.
  Future<void> setMode(FeedPlaybackMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;

    final id = _stateSubject.value.activeSessionId;
    if (id == null) {
      return;
    }

    switch (mode) {
      case FeedPlaybackMode.immersive:
        await coordinator.claimAudio(id);
      case FeedPlaybackMode.preview:
        // A list of previews is a quiet page: give the channel up rather than
        // hold it muted, so a small window behind the page keeps its sound.
        await coordinator.releaseIfOwner(id);
    }
  }

  /// Opens [index] as the page the viewer is looking at: audible, playing.
  ///
  /// The difference from [scrollToIndex] is intent, not mechanics: this is the
  /// list-to-detail step, so it leaves the feed immersive whatever the page was
  /// before.
  Future<PlaybackSession> openDetail(int index, FeedEntryProvider provider) {
    _mode = FeedPlaybackMode.immersive;
    return scrollToIndex(index, provider);
  }

  /// Returns from detail to the list.
  ///
  /// The item stays where the viewer left it. [keepInOverlay] is for the exit
  /// that continues in a small window or PiP: the session keeps playing and
  /// stays pinned, so scrolling the list away from it (or closing the page)
  /// cannot stop the window the viewer is still watching.
  Future<void> closeDetail({bool keepInOverlay = false}) async {
    final state = _stateSubject.value;
    final id = state.activeSessionId;
    if (id == null) {
      return;
    }

    final session = coordinator.sessionFor(id);
    if (keepInOverlay) {
      pinSession(id);
      return;
    }

    if (session != null) {
      _anchors[state.currentIndex] = _FeedAnchor(position: session.handle.position, wasPlaying: session.isPlaying);
      await session.pause();
    }

    _mode = FeedPlaybackMode.preview;
    await coordinator.releaseIfOwner(id);
  }

  /// Keeps [id] alive outside the scroll window.
  ///
  /// Called when a session leaves the list for an overlay; [unpinSession] when
  /// it comes back or is closed for good.
  void pinSession(String id) => _pinned.add(id);

  /// Stops protecting [id] from the scroll window.
  void unpinSession(String id) => _pinned.remove(id);

  /// Moves the feed to [index], opening or resuming that item.
  ///
  /// Returns the on-screen session. A scroll that lands on the item already on
  /// screen is a no-op, so a `PageView` that reports intermediate pages does
  /// not thrash the player.
  Future<PlaybackSession> scrollToIndex(int index, FeedEntryProvider provider) async {
    if (index < 0) {
      throw ArgumentError.value(index, 'index', 'Feed indices start at 0');
    }

    final current = _stateSubject.value;
    if (current.currentIndex == index && current.activeSessionId != null) {
      // Already on screen — a `PageView` reporting the settled page after the
      // pages it passed through. Nothing to open, but the mode may have changed
      // since (detail opened on the item already showing), so the sound policy
      // is re-applied rather than skipped.
      final session = coordinator.sessionFor(current.activeSessionId!)!;
      await _applyModePolicy(session);
      return session;
    }

    await _parkCurrentItem(current);

    final entry = await provider(index);
    _idByIndex[index] = entry.id;

    final session = await _open(entry, index: index);
    await session.play();
    await _applyModePolicy(session);

    _emit(_stateSubject.value.copyWith(currentIndex: index, activeSessionId: entry.id));

    unawaited(_warmNeighbours(index, provider));
    await _pruneOutsideWindow(index);

    return session;
  }

  /// Publishes a feed state, ignoring writes that arrive after [dispose].
  ///
  /// A scroll starts a preload it does not wait for; the page can be gone
  /// before that preload finishes, and its "I am done" report must not reach a
  /// closed stream.
  void _emit(FeedState state) {
    if (_disposed) {
      return;
    }
    _stateSubject.add(state);
  }

  /// Applies the feed's sound rule to [session].
  ///
  /// Immersive means "this item is what the viewer hears"; preview means the
  /// tiles are silent and the channel is given up rather than held muted, so an
  /// overlay window behind the page keeps its sound.
  Future<void> _applyModePolicy(PlaybackSession session) async {
    switch (_mode) {
      case FeedPlaybackMode.immersive:
        await coordinator.claimAudio(session.id);
      case FeedPlaybackMode.preview:
        await coordinator.releaseIfOwner(session.id);
        await session.setMute(muted: true);
    }
  }

  /// Where [index]'s item was left, when it has been watched before.
  Duration? anchorFor(int index) => _anchors[index]?.position;

  /// Whether [index]'s item was playing when the viewer swiped away from it.
  bool? wasPlayingAt(int index) => _anchors[index]?.wasPlaying;

  /// Forgets a remembered position (the viewer tapped "restart").
  void clearAnchor(int index) => _anchors.remove(index);

  /// Stops every session the feed opened and forgets the anchors.
  ///
  /// Pinned sessions survive: they are in an overlay the viewer is still
  /// watching, and leaving the list page is exactly when that matters.
  Future<void> dispose() async {
    _disposed = true;
    for (final id in List<String>.of(_idByIndex.values)) {
      if (_pinned.contains(id)) {
        continue;
      }
      await coordinator.stopSession(id);
    }
    _idByIndex.clear();
    _anchors.clear();
    await _stateSubject.close();
  }

  Future<void> _parkCurrentItem(FeedState current) async {
    final id = current.activeSessionId;
    if (id == null) {
      return;
    }

    final session = coordinator.sessionFor(id);
    if (session == null) {
      return;
    }

    _anchors[current.currentIndex] = _FeedAnchor(position: session.handle.position, wasPlaying: session.isPlaying);
    await session.pause();
  }

  Future<PlaybackSession> _open(FeedEntry entry, {int? index}) async {
    final existing = coordinator.sessionFor(entry.id);
    if (existing != null) {
      return existing;
    }

    final session = await coordinator.startSession(
      id: entry.id,
      source: entry.source,
      candidateSources: entry.candidateSources,
      contentType: entry.contentType,
      metadata: entry.metadata,
      danmaku: entry.createDanmaku?.call(),
      autoPlay: false,
    );

    // Only recorded content has a position worth restoring; a live stream
    // resumes at the live edge by definition.
    final anchor = index == null ? null : _anchors[index]?.position;
    if (anchor != null && entry.contentType == ContentType.recorded) {
      await session.seek(anchor);
    }

    return session;
  }

  Future<void> _warmNeighbours(int index, FeedEntryProvider provider) async {
    final targets = <int>[
      for (var offset = 1; offset <= preloadCount; offset++) ...<int>[index + offset, index - offset],
    ].where((candidate) => candidate >= 0).toList(growable: false);

    if (targets.isEmpty) {
      return;
    }

    _emit(_stateSubject.value.copyWith(isPreloading: true));

    for (final target in targets) {
      if (_disposed) {
        return;
      }
      if (_preloading.contains(target)) {
        continue;
      }
      _preloading.add(target);

      try {
        final entry = await provider(target);
        _idByIndex[target] = entry.id;

        if (coordinator.contains(entry.id)) {
          continue;
        }

        final session = await coordinator.startSession(
          id: entry.id,
          source: entry.source,
          candidateSources: entry.candidateSources,
          contentType: entry.contentType,
          metadata: entry.metadata,
          danmaku: entry.createDanmaku?.call(),
          autoPlay: false,
        );
        await session.setMute(muted: true);
      } on Object catch (_) {
        // A neighbour that fails to warm is not an error the viewer should
        // see: scrolling to it opens it the normal way and reports there.
        _preloading.remove(target);
      }
    }

    _emit(_stateSubject.value.copyWith(isPreloading: false));
  }

  Future<void> _pruneOutsideWindow(int index) async {
    final keep = <String>{};
    for (var offset = 0; offset <= preloadCount; offset++) {
      for (final target in <int>[index, index + offset, index - offset]) {
        final id = _idByIndex[target];
        if (id != null) {
          keep.add(id);
        }
      }
    }

    final doomed = <int, String>{};
    for (final entry in _idByIndex.entries) {
      // A pinned session is in an overlay now; the scroll window does not own
      // it any more, and stopping it would close the small window.
      if (!keep.contains(entry.value) && !_pinned.contains(entry.value)) {
        doomed[entry.key] = entry.value;
      }
    }

    for (final entry in doomed.entries) {
      _idByIndex.remove(entry.key);
      _preloading.remove(entry.key);
      await coordinator.stopSession(entry.value);
    }
  }
}

/// Where a feed item was left.
final class _FeedAnchor {
  const new({required this.position, required this.wasPlaying});

  final Duration position;
  final bool wasPlaying;
}
