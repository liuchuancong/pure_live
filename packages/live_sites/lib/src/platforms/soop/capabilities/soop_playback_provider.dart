import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SOOP's playback: the broadcast's qualities (the `VIEWPRESET` names, best
/// first) and, per quality, the one line of the playlist the stream manager
/// assigns with the player's key appended.
///
/// The line's lease is none: a playlist with its key keeps working. A
/// broadcast that ended since the room was entered keeps its number on the
/// held stream data, and its key request is refused — recovery re-enters the
/// room and asks again. A streamer the platform has no broadcast for, one
/// off the air, blocked, password-protected or for subscribers only says why
/// it cannot play; an age-restricted one needs the platform's own login.
final class SoopPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  SoopPlaybackProvider({required this.site});

  /// The site this capability serves.
  final SoopSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(soopSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: soopSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality));
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(soopSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: soopSiteId, message: '$error', cause: error));
    }
  }
}
