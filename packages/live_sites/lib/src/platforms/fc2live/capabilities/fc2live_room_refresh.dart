import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_manifest.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Fc2Live rooms, refreshed: the member answer room entry makes.
final class Fc2LiveRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  Fc2LiveRoomRefresh({required this.site});

  /// The site this capability serves.
  final Fc2LiveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError(fc2LiveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: fc2LiveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      getRoomForRefresh(roomId: roomId);
}
