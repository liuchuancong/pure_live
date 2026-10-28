import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/features/room/controller/room_controller.dart';
import 'package:pure_live/l10n/translations.dart';

/// Why the room's picture is not the stream right now, and what the viewer
/// can do about it — the derivation the overlay draws from.
///
/// The room controller already knows the facts (the room's state, the
/// playback's state, the error); this maps them onto one honest picture
/// state, in the same spirit as the reference's `pictureStateOf`: the
/// kinds a live room actually goes through, the actions worth offering,
/// and how heavily to dim what is behind.
enum RoomPictureKind {
  /// The stream is on screen; no overlay.
  none,

  /// The viewer paused.
  paused,

  /// Frames are coming.
  buffering,

  /// Opening the room.
  entering,

  /// Opening the stream.
  connecting,

  /// The stream has taken too long to show a frame.
  slow,

  /// The platform said the streamer is off.
  offline,

  /// The streamer is banned.
  banned,

  /// The platform plays a carousel for the offline room.
  carousel,

  /// The room cannot be played (a restriction the platform named).
  unplayable,

  /// The room detail failed to load.
  detailFailed,

  /// The room does not exist.
  notFound,

  /// Playback failed mid-stream.
  playbackFailed,

  /// The stream broke and is being brought back.
  reconnecting,

  /// The replay ran to its end.
  replayEnded,
}

/// What the overlay offers the viewer to do about the state.
enum RoomPictureAction {
  /// Go back to the feed.
  back,

  /// Re-read the room.
  refresh,

  /// Retry the playback.
  retry,

  /// Ask for another line.
  switchLine,

  /// Play the replay or the carousel from its start.
  playAgain,
}

/// How heavily the overlay dims what is behind it.
enum RoomPictureDim {
  /// The picture is visible.
  none,

  /// A veil the text reads over.
  light,

  /// The picture gives way to the message.
  heavy,

  /// The room's cover stands in for the picture.
  cover,
}

/// The overlay's state: what is wrong (or fine), what the viewer can do,
/// how dim the picture is. The state names the kind it leads to (the
/// toggle's icon) wherever that matters.
typedef RoomPictureState = ({
  RoomPictureKind kind,
  String title,
  String? reason,
  List<RoomPictureAction> actions,
  RoomPictureDim dim,
  bool busy,
});

/// The overlay when the stream plays: nothing.
RoomPictureState get _playing => (
  kind: RoomPictureKind.none,
  title: '',
  reason: null,
  actions: const <RoomPictureAction>[],
  dim: RoomPictureDim.none,
  busy: false,
);

RoomPictureState _of(
  RoomPictureKind kind,
  String title, {
  String? reason,
  List<RoomPictureAction> actions = const [],
  RoomPictureDim dim = RoomPictureDim.none,
  bool busy = false,
}) => (kind: kind, title: title, reason: reason, actions: actions, dim: dim, busy: busy);

/// How long an opening stream may take before the overlay calls it slow.
const Duration slowAfter = Duration(seconds: 8);

/// The overlay state of the room as it stands — the mapping from the
/// controller's facts onto what the viewer sees. An error field wins over
/// the playback's states (it is the more specific answer); a room that is
/// not live answers from its broadcast state; everything else reads the
/// playback.
RoomPictureState pictureStateOf(Translations t, RoomState state, {bool slow = false}) {
  // The failure wins over the missing detail: a room that never loaded
  // would otherwise stay on the "opening" spinner forever.
  if (state.error != null) {
    final opening = state.room == null;
    return _of(
      opening ? RoomPictureKind.detailFailed : RoomPictureKind.playbackFailed,
      opening ? t.room.detailFailed : t.room.playbackFailed,
      reason: state.error,
      actions: const [RoomPictureAction.retry, RoomPictureAction.back],
      dim: RoomPictureDim.heavy,
    );
  }
  if (state.room == null) {
    return _of(RoomPictureKind.entering, t.room.openingRoom, busy: true);
  }
  final room = state.room!;
  if (!room.broadcast.isLiveNow) {
    return _offline(t, room);
  }
  // Playback reads: the handle is the room's proof of a stream.
  final playback = state.playback;
  final lines = state.lines.length > 1
      ? const <RoomPictureAction>[RoomPictureAction.switchLine]
      : const <RoomPictureAction>[];
  if (playback.playback == PlayerPlaybackState.error) {
    return _of(
      RoomPictureKind.playbackFailed,
      t.room.playbackFailed,
      reason: state.error,
      actions: [RoomPictureAction.retry, ...lines],
      dim: RoomPictureDim.heavy,
    );
  }
  if (playback.playback == PlayerPlaybackState.buffering) {
    return _of(RoomPictureKind.buffering, t.room.buffering, busy: true);
  }
  return switch (playback.playback) {
    PlayerPlaybackState.idle || PlayerPlaybackState.opening =>
      slow
          ? _of(
              RoomPictureKind.slow,
              t.room.connecting,
              reason: t.room.slowReason,
              actions: [...lines, RoomPictureAction.retry],
              busy: true,
            )
          : _of(RoomPictureKind.connecting, t.room.connecting, busy: true),
    PlayerPlaybackState.paused => _of(RoomPictureKind.paused, t.room.paused),
    PlayerPlaybackState.completed => _of(
      RoomPictureKind.replayEnded,
      t.room.replayEnded,
      actions: const [RoomPictureAction.playAgain, RoomPictureAction.back],
      dim: RoomPictureDim.heavy,
    ),
    PlayerPlaybackState.buffering ||
    PlayerPlaybackState.playing ||
    PlayerPlaybackState.seeking ||
    PlayerPlaybackState.stopping ||
    PlayerPlaybackState.stopped ||
    PlayerPlaybackState.error => _playing,
  };
}

/// The offline room's picture, named by what the platform said.
RoomPictureState _offline(Translations t, LiveRoom room) {
  final state = switch (room.broadcast.effectiveLiveStatus) {
    LiveStatus.banned => _of(
      RoomPictureKind.banned,
      t.room.banned,
      actions: const [RoomPictureAction.refresh, RoomPictureAction.back],
      dim: RoomPictureDim.cover,
    ),
    LiveStatus.carousel => _of(
      RoomPictureKind.carousel,
      t.room.carousel,
      reason: t.room.carouselReason,
      actions: const [RoomPictureAction.refresh, RoomPictureAction.back],
      dim: RoomPictureDim.cover,
    ),
    LiveStatus.replay => _of(
      RoomPictureKind.offline,
      t.room.offlineTitle,
      reason: t.room.offlineReplayReason,
      actions: const [RoomPictureAction.refresh, RoomPictureAction.back],
      dim: RoomPictureDim.cover,
    ),
    LiveStatus.offline || LiveStatus.unknown => _of(
      RoomPictureKind.offline,
      t.room.offlineTitle,
      reason: t.room.offlineReason,
      actions: const [RoomPictureAction.refresh, RoomPictureAction.back],
      dim: RoomPictureDim.cover,
    ),
    _ => _of(
      RoomPictureKind.offline,
      t.room.offlineTitle,
      actions: const [RoomPictureAction.refresh, RoomPictureAction.back],
      dim: RoomPictureDim.cover,
    ),
  };
  return state;
}

/// Whether the room's opening stream has outlived the overlay's patience;
/// the room page's timer owns it and the overlay reads it from here.
final roomSlowProvider = NotifierProvider<RoomSlowController, bool>(RoomSlowController.new);

/// The room page's slow-open flag, timed by the page and read by the
/// overlay's derivation.
final class RoomSlowController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Whether the room's stream is on screen already.
  bool get slow => state;

  /// The stream is taking the overlay's patience.
  set slow(bool value) => state = value;
}
