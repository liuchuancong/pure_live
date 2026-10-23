import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_manifest.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TikTok's playback: the qualities and lines of the streams a room entry
/// brought (or a fresh entry when none is kept).
///
/// The pull URLs are signed and expire for about 14 days, so each line
/// carries the lease of its `expire`; an expired HLS playlist ends playback,
/// an established FLV connection keeps flowing, and the lease says so. An
/// offline room, a restricted one and one without a readable stream are
/// errors that name the reason, never an empty list.
final class TiktokPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  TiktokPlaybackProvider({required this.site});

  /// The site this capability serves.
  final TiktokSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on TiktokFailure catch (failure) {
      return left(failure.toLiveSiteError(tiktokSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: tiktokSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality));
    } on TiktokFailure catch (failure) {
      return left(failure.toLiveSiteError(tiktokSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: tiktokSiteId, message: '$error', cause: error));
    }
  }
}
