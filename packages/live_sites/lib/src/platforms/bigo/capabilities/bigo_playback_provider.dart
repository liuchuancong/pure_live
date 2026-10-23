import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_play_format_source.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_endpoints.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bigo's playback: the one quality, and a playlist that is re-resolved on
/// every open.
///
/// Bigo's web studio hands out exactly one stream, `直播自动`, and the playlist
/// comes only with a web token's *first* use. So the quality list is read from
/// the reusable token (one request when a token is kept), while the lines take a
/// fresh token and answer (three requests) — a playlist URL is good for the one
/// playback it was made for, which [LivePlayLine.singleUse] says to the player.
/// The address carries no expiry of its own, so there is no lease to keep: the
/// next playback asks again.
///
/// A login gate is an authentication failure, a password or paid room, an offline
/// room and a live room with no playlist are content-unavailable — never an
/// empty list. The segments of the playlist are scrambled (see
/// `BigoHlsProtection`); whoever plays it relays them.
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
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      final studio = await site.refresh(roomId);
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
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    if (quality != null && quality.qualityId != BigoEndpoints.qualityId) {
      return left(
        LiveSiteError.invalidArgument(
          siteId: bigoSiteId,
          message: 'quality ${quality.qualityId} is not a bigo quality',
        ),
      );
    }
    try {
      final hls = await site.playPlaylist(roomId);
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
