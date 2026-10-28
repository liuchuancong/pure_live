import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_room_provider.dart';
import 'package:live_sites/src/platforms/douyu/douyu_manifest.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's refresh reads: the room detail (`betard` included) is the one
/// metadata request, and the recorder needs nothing beyond it.
final class DouyuRoomRefresh implements LiveRoomRefresh {
  /// Serves [rooms].
  DouyuRoomRefresh({required this.rooms});

  /// The room provider whose detail read this capability shares.
  final DouyuRoomProvider rooms;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await rooms.detail(roomId));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError(douyuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyuSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      getRoomForRefresh(roomId: roomId);
}
