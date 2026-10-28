import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_manifest.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Sixroom rooms, refreshed: the room summary (no stream, no danmaku handles).
final class SixroomRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  SixroomRoomRefresh({required this.site});

  /// The site this capability serves.
  final SixroomSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.summary(roomId));
    } on SixroomFailure catch (failure) {
      return left(failure.toLiveSiteError(sixroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: sixroomSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on SixroomFailure catch (failure) {
      return left(failure.toLiveSiteError(sixroomSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: sixroomSiteId, message: '$error', cause: error));
    }
  }
}
