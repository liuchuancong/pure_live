import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_manifest.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Pandalive rooms, refreshed: the member answer alone, without the play request a first visit makes.
final class PandaliveRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  PandaliveRoomRefresh({required this.site});

  /// The site this capability serves.
  final PandaliveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.refreshRoom(roomId));
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(pandaliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: pandaliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(pandaliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: pandaliveSiteId, message: '$error', cause: error));
    }
  }
}
