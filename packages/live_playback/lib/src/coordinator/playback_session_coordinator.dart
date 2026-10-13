import 'dart:async';

import 'package:live_playback/src/config/playback_config.dart';
import 'package:live_playback/src/model/content_type.dart';
import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/session/playback_session.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:rxdart/rxdart.dart';

/// Keeps the app's business sessions (windows) in order.
///
/// One session per room: the list, the feed and the multi-view grid all ask
/// this coordinator for a session by id and get the same one back. It is the
/// composition root between business requests and the [PlayerKernel], and it
/// owns the two rules that only make sense across windows:
///
/// - **one audio channel**: the window that acquires ownership is unmuted and
///   every other window is muted, because two live rooms talking at once is
///   never what the viewer asked for;
/// - **one danmaku switch**: "hide all chat" must reach every open window,
///   not just the one the button sits in.
///
/// Actual audio *focus* (interruptions, ducking, other apps) is the kernel
/// audio driver's job — the host attaches `MediaSessionDriver` to the kernel.
/// This coordinator only decides which of our own windows may be heard.
final class PlaybackSessionCoordinator {
  /// Creates a session coordinator.
  new({required this.kernel, this.config = PlaybackConfig.defaults});

  /// The media kernel every session is created from.
  final PlayerKernel kernel;

  /// Global configuration (device profile, audio defaults).
  final PlaybackConfig config;

  final Map<String, PlaybackSession> _sessions = <String, PlaybackSession>{};

  final BehaviorSubject<String?> _currentSessionId = BehaviorSubject<String?>.seeded(null);

  final BehaviorSubject<List<String>> _sessionIds = BehaviorSubject<List<String>>.seeded(const <String>[]);

  /// Every open session, keyed by business id.
  Map<String, PlaybackSession> get sessions => Map.unmodifiable(_sessions);

  /// The ids of the open sessions, in creation order.
  ValueStream<List<String>> get sessionIds => _sessionIds.stream;

  /// The id of the session that owns the audio channel, if any.
  String? get currentSessionId => _currentSessionId.value;

  /// Stream of the audio owner's id.
  ValueStream<String?> get currentSessionIdStream => _currentSessionId.stream;

  /// The session that owns the audio channel, if any.
  PlaybackSession? get currentSession => _sessions[currentSessionId];

  /// Stream of the audio owner, for surfaces that render "the" video.
  Stream<PlaybackSession?> get currentSessionStream =>
      _currentSessionId.stream.map((id) => id == null ? null : _sessions[id]);

  /// The session with [id], when it is open.
  PlaybackSession? sessionFor(String id) => _sessions[id];

  /// Whether a session with [id] is open.
  bool contains(String id) => _sessions.containsKey(id);

  // --- Session lifecycle ---

  /// Opens a session for [id], or returns the existing one.
  ///
  /// [source] is the resolved playback URL; [candidateSources] are the other
  /// lines and qualities the recovery ladder may escalate to. [danmaku] is
  /// the room's chat controller, when the platform has one — the caller owns
  /// its transport, because only the site layer knows the protocol.
  Future<PlaybackSession> startSession({
    required String id,
    required PlayerSource source,
    List<PlayerSource> candidateSources = const <PlayerSource>[],
    ContentType contentType = ContentType.live,
    PlaybackMetadata metadata = PlaybackMetadata.none,
    DanmakuController? danmaku,
    PlayerConfig? playerConfig,
    bool autoPlay = true,
  }) async {
    final existing = _sessions[id];
    if (existing != null) {
      return existing;
    }

    final handle = await kernel.create(
      source: _enrich(source, metadata),
      config:
          playerConfig ??
          PlayerConfig.defaults.copyWith(
            autoPlay: autoPlay,
            volume: config.defaultVolume,
            playbackRate: config.defaultPlaybackRate,
          ),
    );

    final session = PlaybackSession(
      id: id,
      handle: handle,
      kernel: kernel,
      contentType: contentType,
      sourceCandidates: candidateSources,
      metadata: metadata,
      danmaku: danmaku,
    );

    _sessions[id] = session;
    _publishIds();
    return session;
  }

  /// Registers an already-built session.
  ///
  /// For hosts that open the handle themselves (a resumed background window)
  /// and hand the session over afterwards.
  void adopt(PlaybackSession session) {
    if (_sessions.containsKey(session.id)) {
      return;
    }
    _sessions[session.id] = session;
    _publishIds();
  }

  /// Stops a session and releases its kernel handle.
  Future<void> stopSession(String id) async {
    final session = _sessions.remove(id);
    if (session == null) {
      return;
    }

    if (currentSessionId == id) {
      _currentSessionId.add(null);
    }

    await session.dispose();
    await kernel.release(session.handle.id);
    _publishIds();
  }

  /// Stops every session.
  Future<void> stopAll() async {
    for (final id in _sessions.keys.toList(growable: false)) {
      await stopSession(id);
    }
  }

  // --- Audio ownership ---

  /// Gives the audio channel to the session with [id].
  ///
  /// The owner is unmuted; every other session is muted. Playback itself is
  /// not touched: a muted window in a multi-view grid keeps its picture.
  Future<void> claimAudio(String id) async {
    final owner = _sessions[id];
    if (owner == null) {
      throw StateError('No open session for id: $id');
    }

    _currentSessionId.add(id);

    await Future.wait(<Future<void>>[
      for (final entry in _sessions.entries)
        if (entry.key == id) entry.value.setMute(muted: false) else entry.value.setMute(muted: true),
    ]);
  }

  /// Releases the audio channel, muting every session.
  ///
  /// Used when the app stops being audible on purpose (a phone call, the
  /// viewer leaving the player for a page with its own sound).
  Future<void> releaseAudio() async {
    _currentSessionId.add(null);
    await muteAll();
  }

  /// Mutes every session (the "mute everything" button).
  Future<void> muteAll() async {
    await Future.wait(_sessions.values.map((session) => session.setMute(muted: true)));
  }

  /// Restores the one-audio-channel rule: the owner audible, the rest muted.
  ///
  /// Without an owner the first session becomes one, so the button never
  /// leaves the app silent with no way back.
  Future<void> unmuteAll() async {
    final id = currentSessionId ?? _sessions.keys.firstOrNull;
    if (id == null) {
      return;
    }
    await claimAudio(id);
  }

  // --- Danmaku ownership ---

  /// Turns danmaku on or off for every open session.
  ///
  /// The preference is remembered per session, so a window opened later
  /// inherits the global switch rather than defaulting to on.
  Future<void> setAllDanmakuEnabled({required bool enabled}) async {
    _danmakuEnabled = enabled;
    for (final session in _sessions.values) {
      session.setDanmakuEnabled(enabled: enabled);
    }
  }

  /// Whether the global danmaku switch is on.
  bool get danmakuEnabled => _danmakuEnabled;

  bool _danmakuEnabled = true;

  // --- Housekeeping ---

  /// Disposes every session and the coordinator's streams.
  Future<void> dispose() async {
    await stopAll();
    await _currentSessionId.close();
    await _sessionIds.close();
  }

  void _publishIds() {
    _sessionIds.add(List<String>.unmodifiable(_sessions.keys));
  }

  /// Rides the room's identity on the source.
  ///
  /// The kernel's audio driver builds the notification item from the source it
  /// was given, so a title and a cover that live only in [PlaybackMetadata]
  /// would never reach the lock screen. Copying them onto the source is what
  /// makes the notification say "某某的直播间" instead of the stream's file name.
  PlayerSource _enrich(PlayerSource source, PlaybackMetadata metadata) {
    if (metadata.isEmpty) {
      return source;
    }

    final name = metadata.displayName;
    final cover = metadata.coverUrl;
    final hasCover = cover != null && cover.trim().isNotEmpty;

    return source.copyWith(
      title: source.hasTitle ? source.title : (name.isEmpty ? null : name),
      metadata: hasCover ? <String, Object?>{...source.metadata, 'artUri': cover} : source.metadata,
    );
  }
}
