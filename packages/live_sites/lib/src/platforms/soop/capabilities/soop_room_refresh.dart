import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Soop rooms, refreshed: the same one detail read room entry makes; no playback probe is added.
final class SoopRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  SoopRoomRefresh({required this.site});

  /// The site this capability serves.
  final SoopSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(soopSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: soopSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      getRoomForRefresh(roomId: roomId);
}
