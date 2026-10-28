import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Looklive rooms, refreshed: the room without media, as the follow lists ask.
final class LookliveRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  LookliveRoomRefresh({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.detail(roomId, withMedia: false));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }
}
