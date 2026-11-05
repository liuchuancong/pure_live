import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
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

/// Bigo's playback: one quality, and a stream this build cannot open.
///
/// Bigo's web studio hands out exactly one stream, `直播自动`, and a playlist URL
/// that is good for the one playback it was made for. The segments behind that
/// playlist are scrambled — the media playlist carries
/// `#EXT-X-BIGO-WEB-PROTECTION:SEED=…` and a seed-derived XOR stream hides the
/// head of every segment (`BigoHlsProtection` holds that arithmetic) — so
/// playing what the site hands out is a black picture, and unscrambling it is a
/// job for something between the CDN and the player, which this app does not
/// run. [getLines] therefore answers the reason instead of an address, and
/// spends no single-use token doing it; [getQualities] still reports what the
/// studio offers, because that is a fact about the room.
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
    // the head of every segment - `BigoHlsProtection` holds the arithmetic,
    // which needs something between the CDN and the player to be of any use.
    // This app plays what the platform hands out and runs no such relay, so the
    // answer is the reason, before the room is left with a black picture and a
    // spinner. The address is not asked for either: it is good for the one
    // playback it was made for, and spending it to learn nothing helps no one.
    return left(
      const LiveSiteError.unsupported(
        siteId: bigoSiteId,
        message: 'Bigo 的网页直播流是逐段加密的（播放列表带 #EXT-X-BIGO-WEB-PROTECTION），本版不转码这段流，无法播放',
      ),
    );
  }
}
