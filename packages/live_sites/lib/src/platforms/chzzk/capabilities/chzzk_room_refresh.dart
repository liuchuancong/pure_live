import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_manifest.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CHZZK's refresh reads: the channel and its live, the room's two requests,
/// with no playback store bookkeeping and no danmaku handles.
final class ChzzkRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  ChzzkRoomRefresh({required this.site});

  /// The site this capability serves.
  final ChzzkSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      final read = await site.read(roomId);
      return right(ChzzkRoomParser.room(read.owner, read.live));
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      getRoomForRefresh(roomId: roomId);
}
