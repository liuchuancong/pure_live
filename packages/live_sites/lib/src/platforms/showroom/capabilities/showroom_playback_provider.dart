import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// SHOWROOM's playback: the `hls` tiers of the room's
/// `live/streaming_url` (原画 the default, 中画质 and 低画质 below, the
/// adaptive 自动 master last), best first.
///
/// The rows room entry kept are served without a request; a room that was
/// never entered, or whose entry could not read them, asks again. A room
/// entry called offline has no stream without a request, and a quality the
/// room does not offer is an error that says so — never an empty list. The
/// URLs are not signed and do not expire, so no line carries a lease.
final class ShowroomPlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  ShowroomPlaybackProvider({required this.site});

  /// The site this capability serves.
  final ShowroomSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError('showroom'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'showroom', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError('showroom'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'showroom', message: '$error', cause: error));
    }
  }
}
