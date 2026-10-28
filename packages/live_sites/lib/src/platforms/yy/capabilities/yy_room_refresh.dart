import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/yy_manifest.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Yy rooms, refreshed: the follow refresh (liveInfoDetail), not the full entry read.
final class YyRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  YyRoomRefresh({required this.site});

  /// The site this capability serves.
  final YySite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.refreshRoom(roomId));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
  }
}
