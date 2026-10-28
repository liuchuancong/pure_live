import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/niconico/niconico_manifest.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Niconico rooms, refreshed: the watch answer room entry makes.
final class NiconicoRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  NiconicoRoomRefresh({required this.site});

  /// The site this capability serves.
  final NiconicoSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError(niconicoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: niconicoSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      getRoomForRefresh(roomId: roomId);
}
