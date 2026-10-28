import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_manifest.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugoulive rooms, refreshed: the room info alone, without the stream request a first visit makes.
final class KugouliveRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  KugouliveRoomRefresh({required this.site});

  /// The site this capability serves.
  final KugouliveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.refreshRoom(roomId));
    } on KugouliveFailure catch (failure) {
      return left(failure.toLiveSiteError(kugouliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kugouliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on KugouliveFailure catch (failure) {
      return left(failure.toLiveSiteError(kugouliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kugouliveSiteId, message: '$error', cause: error));
    }
  }
}
