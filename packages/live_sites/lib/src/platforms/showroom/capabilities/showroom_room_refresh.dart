import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Showroom rooms, refreshed: the profile and live info alone, without the stream rows a first visit reads when live.
final class ShowroomRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  ShowroomRoomRefresh({required this.site});

  /// The site this capability serves.
  final ShowroomSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.refreshRoom(roomId));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(showroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: showroomSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(showroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: showroomSiteId, message: '$error', cause: error));
    }
  }
}
