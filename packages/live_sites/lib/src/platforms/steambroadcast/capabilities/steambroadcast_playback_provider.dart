import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart' show siteId;
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Steam Broadcast's playback: the adaptive quality 自适应 HLS, then one per
/// variant of the checked HLS master when it has several (`1080p60`…), from
/// the stream data of the room's entry (or a fresh entry when none is kept).
///
/// The master is the one line, and it is long-lived and unsigned past its
/// CDN parameters, so it carries no headers and no lease; a broadcaster that
/// is offline, waiting or in an unknown state, one whose account may not
/// broadcast, a broadcast for subscribers only and one whose media failed to
/// load or to check are errors that name the reason, never an empty list.
final class SteambroadcastPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  SteambroadcastPlaybackProvider({required this.site});

  /// The site this capability serves.
  final SteambroadcastSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(siteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: siteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality));
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(siteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: siteId, message: '$error', cause: error));
    }
  }
}
