import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_ingest.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_endpoints.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bigo's playback: the one quality and the playlist to play.
///
/// Bigo's web studio hands out exactly one stream, `直播自动`, and a playlist
/// URL that is good for the one playback it was made for. The segments behind
/// that playlist are scrambled — the media playlist carries
/// `#EXT-X-BIGO-WEB-PROTECTION:SEED=…` and a seed-derived XOR stream hides the
/// head of every segment — so the site declares [LiveSiteIngestNeed.segmentTransform]
/// on its runtime info and the app's `media_core_ingest` relay restores every
/// segment with `BigoHlsProtection` before the player reads it.
///
/// A login gate is an authentication failure, a password or paid room, an offline
/// room and a live room with no playlist are content-unavailable — never an
/// empty list.
final class BigoPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  BigoPlaybackProvider({required this.site});

  /// The site this capability serves.
  final BigoSite site;

  /// The one quality this platform offers.
  static final LivePlayQuality quality = LivePlayQuality.of(
    label: BigoEndpoints.qualityLabel,
    qualityId: BigoEndpoints.qualityId,
  );

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      final studio = await site.refresh(room.roomId);
      final error = studio.streamError;
      if (error != null) throw error;
      return right([quality]);
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError(bigoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bigoSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    if (quality != null && quality.qualityId != BigoEndpoints.qualityId) {
      return left(
        LiveSiteError.invalidArgument(
          siteId: bigoSiteId,
          message: 'quality ${quality.qualityId} is not a bigo quality',
        ),
      );
    }
    // Bigo's web HLS is scrambled: the media playlist names a seed
    // (`#EXT-X-BIGO-WEB-PROTECTION:SEED=…`) and a stream from that seed hides
    // the head of every segment. The app's ingest relay (media_core_ingest)
    // restores each segment with `BigoHlsProtection`; the site hands out the
    // playlist and declares that need in `runtimeInfo.ingest`.
    try {
      final hls = await site.playPlaylist(room.roomId);
      return right([
        LivePlayLine.of(
          url: '$hls',
          format: LiveStreamFormat.hls,
          formatSource: LivePlayFormatSource.declared,
          headers: BigoEndpoints.headers,
          lineLabel: hls.host,
          singleUse: true,
        ),
      ]);
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError(bigoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bigoSiteId, message: '$error', cause: error));
    }
  }
}
