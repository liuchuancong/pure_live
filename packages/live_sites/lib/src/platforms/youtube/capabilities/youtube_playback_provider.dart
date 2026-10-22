import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_play_parser.dart';
import 'package:live_sites/src/platforms/youtube/youtube_manifest.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YouTube's playback: the ANDROID `player` answer's `streamingData`, read off
/// a fresh room detail — the live `hlsManifestUrl` (fetched and parsed into its
/// `#EXT-X-STREAM-INF` variants), a `dashManifestUrl` and the progressive
/// `formats[]`.
///
/// There is no signature to make and no play request beyond the player itself;
/// each line's lease is read from its own `expire`. A room that offers no line
/// for this client is stream-unavailable, and every URL is checked against the
/// media host allowlist before it is handed out.
final class YoutubePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  YoutubePlaybackProvider({required this.site});

  /// The site this capability serves.
  final YoutubeSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      final handle = await _handle(roomId);
      final variants = await _variants(handle);
      final qualities = YoutubePlayParser.qualities(
        variants: variants,
        hlsManifestUrl: handle.hlsManifestUrl,
        dashManifestUrl: handle.dashManifestUrl,
        progressive: handle.formats,
      );
      if (qualities.isEmpty) {
        throw const YouTubeFailure(YoutubeFailureKind.streamUnavailable, 'streamingData: no playable representation');
      }
      return right(qualities);
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError(youtubeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: youtubeSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      final handle = await _handle(roomId);
      final variants = await _variants(handle);
      final lines = YoutubePlayParser.lines(
        variants: variants,
        videoId: handle.videoId,
        issuedAt: handle.issuedAt,
        hlsManifestUrl: handle.hlsManifestUrl,
        dashManifestUrl: handle.dashManifestUrl,
        progressive: handle.formats,
        qualityId: quality?.qualityId,
      );
      if (lines.isEmpty) {
        throw const YouTubeFailure(YoutubeFailureKind.streamUnavailable, 'streamingData: no playable URL');
      }
      return right(lines);
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError(youtubeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: youtubeSiteId, message: '$error', cause: error));
    }
  }

  /// The room's stream handle; a room that names none is stream-unavailable.
  Future<YoutubeRoomData> _handle(String roomId) async {
    final room = await site.detail(roomId);
    final handle = room.runtime.streamHandle;
    if (handle is! YoutubeRoomData) {
      throw YouTubeFailure(YoutubeFailureKind.streamUnavailable, 'room page: ${room.roomId} names no stream');
    }
    return handle;
  }

  /// The HLS master variants of [handle]'s `hlsManifestUrl`; empty when there is
  /// no manifest URL (the DASH and progressive tiers then stand alone).
  Future<List<YoutubeVariant>> _variants(YoutubeRoomData handle) async {
    final master = handle.hlsManifestUrl;
    if (master == null || master.isEmpty) return const [];
    final response = await site.fetchMaster(master, handle.videoId);
    if (response.status < 200 || response.status >= 300) {
      throw YouTubeFailure(YoutubeFailureKind.network, 'hls master: HTTP ${response.status}');
    }
    final uri = Uri.tryParse(master);
    if (uri == null) return const [];
    return YoutubePlayParser.variants(response.text, uri);
  }
}
