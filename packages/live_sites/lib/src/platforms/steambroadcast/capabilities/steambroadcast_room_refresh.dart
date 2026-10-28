import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_manifest.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Steambroadcast rooms, refreshed: the broadcast without media, as the follow lists ask.
final class SteambroadcastRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  SteambroadcastRoomRefresh({required this.site});

  /// The site this capability serves.
  final SteambroadcastSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.detail(roomId, media: false));
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(steambroadcastSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: steambroadcastSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(steambroadcastSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: steambroadcastSiteId, message: '$error', cause: error));
    }
  }
}
