import 'package:live_playback/src/model/content_type.dart';
import 'package:live_playback/src/model/layout_strategy.dart';
import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/model/playback_state.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';

/// A read-only view of one playback session at a point in time.
///
/// This is the answer to "what is this room doing right now": its business
/// phase, the kernel's truth about the picture and the sound, and whether
/// its danmaku is connected and visible. A PiP window, a multi-view tile or
/// a debugging overlay all read this instead of reaching into the session.
final class PlaybackSessionSnapshot {
  /// Creates a session snapshot.
  const new({
    required this.id,
    required this.contentType,
    required this.state,
    required this.metadata,
    required this.volume,
    required this.muted,
    required this.danmakuEnabled,
    required this.danmaku,
    this.player,
    this.isPrimary = false,
  });

  /// The business id of the session (a room id, a video id).
  final String id;

  /// Live or recorded.
  final ContentType contentType;

  /// Business state: phase, quality, line, recovery attempts.
  final PlaybackState state;

  /// Room identity: title, streamer, cover.
  final PlaybackMetadata metadata;

  /// Audio volume `0.0`–`1.0` as last set.
  final double volume;

  /// Whether the session's sound is muted.
  final bool muted;

  /// Whether danmaku is currently visible for this session.
  ///
  /// False while the session is in a thumbnail presentation (PiP/floating)
  /// even when the viewer's own preference is "on".
  final bool danmakuEnabled;

  /// The danmaku connection state, when a controller is attached.
  final DanmakuSessionState? danmaku;

  /// The kernel's combined snapshot, when a handle is attached.
  final PlayerHandleSnapshot? player;

  /// Whether this session currently owns the audio channel.
  final bool isPrimary;

  /// Whether a danmaku controller is attached at all.
  bool get hasDanmaku => danmaku != null;

  /// Whether danmaku is connected and receiving.
  bool get isDanmakuConnected => danmaku?.isConnected ?? false;

  /// The playback position, when the kernel reports one.
  Duration get position => player?.playback.position ?? Duration.zero;

  /// Whether the picture is playing.
  bool get isPlaying => player?.playback.isPlaying ?? false;

  /// Copy with the primary flag replaced.
  PlaybackSessionSnapshot asPrimary({required bool primary}) {
    return PlaybackSessionSnapshot(
      id: id,
      contentType: contentType,
      state: state,
      metadata: metadata,
      volume: volume,
      muted: muted,
      danmakuEnabled: danmakuEnabled,
      danmaku: danmaku,
      player: player,
      isPrimary: primary,
    );
  }
}

/// A unified, immutable snapshot of the whole playback system.
///
/// The UI observes this instead of assembling state from a handful of
/// controllers: one stream answers both "what is the primary room doing"
/// and "what is that other window doing", plus how the picture is presented
/// and on what kind of device.
final class PlaybackSystemState {
  /// Creates a system snapshot.
  const new({
    required this.sessions,
    required this.presentationMode,
    required this.presentationTransitioning,
    required this.deviceProfile,
    required this.isBackgrounded,
    this.primarySessionId,
    this.overlaySessionId,
    this.allMuted = false,
    this.allDanmakuDisabled = false,
  });

  /// The state before anything started.
  static const PlaybackSystemState idle = PlaybackSystemState(
    sessions: <String, PlaybackSessionSnapshot>{},
    presentationMode: PresentationMode.normal,
    presentationTransitioning: false,
    deviceProfile: DeviceProfile.mobile,
    isBackgrounded: false,
  );

  /// Every active session, keyed by business id.
  final Map<String, PlaybackSessionSnapshot> sessions;

  /// The current presentation mode of the picture.
  final PresentationMode presentationMode;

  /// Whether a presentation transition is in flight.
  final bool presentationTransitioning;

  /// What kind of device the system was told it is running on.
  final DeviceProfile deviceProfile;

  /// Whether the app is currently not visible.
  final bool isBackgrounded;

  /// The id of the session that owns the audio channel.
  final String? primarySessionId;

  /// The id of the session showing in an overlay (PiP or the small window).
  ///
  /// A page going away can hand its video to an overlay instead of stopping it,
  /// and the overlay outlives the page: this is how the rest of the app knows
  /// which window is the small one, and which session must not be recycled when
  /// a list scrolls away from it.
  final String? overlaySessionId;

  /// Whether every session is muted by the global mute.
  final bool allMuted;

  /// Whether every session has danmaku turned off by the global switch.
  final bool allDanmakuDisabled;

  /// The audio owner's snapshot, when there is one.
  PlaybackSessionSnapshot? get primary => primarySessionId == null ? null : sessions[primarySessionId];

  /// The overlay window's snapshot, when one is showing.
  PlaybackSessionSnapshot? get overlay => overlaySessionId == null ? null : sessions[overlaySessionId];

  /// Whether any session exists.
  bool get hasSessions => sessions.isNotEmpty;

  /// Whether the picture is in an overlay (PiP or floating) presentation.
  bool get isOverlay => presentationMode.isOverlay;

  /// How a video surface should be laid out right now.
  ///
  /// Overlay presentation wins: a thumbnail follows the video's shape on
  /// every device. Otherwise the profile and the primary picture decide.
  LayoutStrategy get layoutStrategy => LayoutStrategy.forProfile(
    deviceProfile,
    primary?.player?.geometry.orientation.effectiveOrientation ?? VideoOrientation.unknown,
    isOverlay: isOverlay,
  );

  /// The snapshot for a specific session, when it exists.
  PlaybackSessionSnapshot? snapshotFor(String id) => sessions[id];

  /// A copy with fields replaced.
  ///
  /// [primarySessionId] can be *cleared* by passing [clearPrimary]; a null
  /// value alone means "leave it".
  PlaybackSystemState copyWith({
    Map<String, PlaybackSessionSnapshot>? sessions,
    PresentationMode? presentationMode,
    bool? presentationTransitioning,
    DeviceProfile? deviceProfile,
    bool? isBackgrounded,
    String? primarySessionId,
    bool clearPrimary = false,
    String? overlaySessionId,
    bool clearOverlay = false,
    bool? allMuted,
    bool? allDanmakuDisabled,
  }) {
    return PlaybackSystemState(
      sessions: sessions ?? this.sessions,
      presentationMode: presentationMode ?? this.presentationMode,
      presentationTransitioning: presentationTransitioning ?? this.presentationTransitioning,
      deviceProfile: deviceProfile ?? this.deviceProfile,
      isBackgrounded: isBackgrounded ?? this.isBackgrounded,
      primarySessionId: clearPrimary ? null : (primarySessionId ?? this.primarySessionId),
      overlaySessionId: clearOverlay ? null : (overlaySessionId ?? this.overlaySessionId),
      allMuted: allMuted ?? this.allMuted,
      allDanmakuDisabled: allDanmakuDisabled ?? this.allDanmakuDisabled,
    );
  }
}
