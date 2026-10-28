import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kick/kick_manifest.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kick's refresh reads: the channel answer without the chatroom runtime
/// handles a first visit attaches.
final class KickRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  KickRoomRefresh({required this.site});

  /// The site this capability serves.
  final KickSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right((await site.channel(roomId)).room);
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError(kickSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kickSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      getRoomForRefresh(roomId: roomId);
}
