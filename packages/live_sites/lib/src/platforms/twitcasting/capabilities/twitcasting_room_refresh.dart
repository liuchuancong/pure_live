import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_manifest.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Twitcasting rooms, refreshed: the streamserver answer alone (state and broadcast), not the channel page.
final class TwitcastingRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  TwitcastingRoomRefresh({required this.site});

  /// The site this capability serves.
  final TwitcastingSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.refreshRoom(roomId));
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError(twitcastingSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitcastingSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError(twitcastingSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitcastingSiteId, message: '$error', cause: error));
    }
  }
}
