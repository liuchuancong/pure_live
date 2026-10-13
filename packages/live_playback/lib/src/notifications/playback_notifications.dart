import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/session/playback_session.dart';
import 'package:media_core_mediasession/media_core_mediasession.dart';

/// Names the playing room on the system's media surfaces.
///
/// The surfaces themselves — the Android media notification, the iOS lock
/// screen, Windows SMTC, Linux MPRIS, plus audio focus and interruptions —
/// belong to media_core's `MediaSessionDriver`, which the host attaches to the
/// kernel before anything plays. The driver already republishes play state,
/// position and controls from the handle it is watching; a second publisher
/// here would be overwritten on the next transport change.
///
/// What the driver cannot know is *who* is being watched. This coordinator
/// fills that in: when a session becomes the active one, it publishes a media
/// item carrying the room title, the streamer and the cover. It also enriches
/// the player source with the same facts, so the driver's own item builder
/// names the room correctly from the first frame rather than showing a URL.
final class PlaybackNotifications {
  /// Creates the coordinator.
  ///
  /// [driver] is the kernel's audio driver, when the host attached one. A host
  /// that has not wired system media surfaces yet passes null and everything
  /// else keeps working — there is simply no notification to name.
  new({this.driver});

  /// The host's media session driver, when one is attached.
  final MediaSessionDriver? driver;

  /// Whether a system media surface is available.
  bool get isAttached => driver?.handler != null;

  /// Publishes [session]'s room identity as the current media item.
  ///
  /// Called when a room starts or regains the audio channel. A session without
  /// metadata (a host that never resolved a title) is left to the driver's own
  /// item, which falls back to the source's title and then its file name.
  void publishSession(PlaybackSession? session) {
    final handler = driver?.handler;
    if (handler == null) {
      return;
    }

    if (session == null) {
      handler
        ..publishIdle()
        ..clearMediaItem();
      return;
    }

    handler.publishMediaItem(itemFor(session.id, session.metadata));
  }

  /// Forgets the current media item.
  void clear() {
    final handler = driver?.handler;
    if (handler == null) {
      return;
    }
    handler
      ..publishIdle()
      ..clearMediaItem();
  }

  /// The media item describing a room.
  ///
  /// Exposed so a host with its own publisher — a music module with a queue,
  /// say — builds the same item instead of a second, differently worded one.
  MediaSessionItem itemFor(String id, PlaybackMetadata metadata) {
    return MediaSessionItem(
      id: id,
      title: metadata.displayName.isEmpty ? id : metadata.displayName,
      artist: metadata.streamerName ?? '',
      artUri: _uriOf(metadata.coverUrl),
    );
  }

  Uri? _uriOf(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    return Uri.tryParse(url);
  }
}
