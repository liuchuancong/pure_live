import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/inke/inke_manifest.dart';
import 'package:live_sites/src/platforms/inke/inke_site.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke rooms, refreshed: the share page alone, without the broadcast a first visit resolves.
final class InkeRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  InkeRoomRefresh({required this.site});

  /// The site this capability serves.
  final InkeSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.refreshRoom(roomId));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError(inkeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: inkeSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on InkeFailure catch (failure) {
      return left(failure.toLiveSiteError(inkeSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: inkeSiteId, message: '$error', cause: error));
    }
  }
}
