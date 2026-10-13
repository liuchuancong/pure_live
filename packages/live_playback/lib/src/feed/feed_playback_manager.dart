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
/// for windows.
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

  /// Current feed state.
  ValueStream<FeedState> get state => _stateSubject.stream;

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
      return coordinator.sessionFor(current.activeSessionId!)!;
    }

    await _parkCurrentItem(current);

    final entry = await provider(index);
    _idByIndex[index] = entry.id;

    final session = await _open(entry, index: index);
    await session.play();
    await coordinator.claimAudio(entry.id);

    _stateSubject.add(_stateSubject.value.copyWith(currentIndex: index, activeSessionId: entry.id));

    unawaited(_warmNeighbours(index, provider));
    await _pruneOutsideWindow(index);

    return session;
  }

  /// Where [index]'s item was left, when it has been watched before.
  Duration? anchorFor(int index) => _anchors[index]?.position;

  /// Whether [index]'s item was playing when the viewer swiped away from it.
  bool? wasPlayingAt(int index) => _anchors[index]?.wasPlaying;

  /// Forgets a remembered position (the viewer tapped "restart").
  void clearAnchor(int index) => _anchors.remove(index);

  /// Stops every session the feed opened and forgets the anchors.
  Future<void> dispose() async {
    for (final id in List<String>.of(_idByIndex.values)) {
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

    _stateSubject.add(_stateSubject.value.copyWith(isPreloading: true));

    for (final target in targets) {
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

    _stateSubject.add(_stateSubject.value.copyWith(isPreloading: false));
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
      if (!keep.contains(entry.value)) {
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
