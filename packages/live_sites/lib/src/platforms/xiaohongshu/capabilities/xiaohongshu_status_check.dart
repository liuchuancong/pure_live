import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Xiaohongshu's one-bit status ask, read through the same refresh the follow and
/// history lists use.
final class XiaohongshuStatusCheck implements LiveStatusCheck {
  /// Serves [refresh].
  XiaohongshuStatusCheck({required this.refresh});

  /// The refresh read this capability shares.
  final LiveRoomRefresh refresh;

  @override
  Future<Either<LiveSiteError, bool>> getLiveStatus({required LiveRoom room}) async =>
      (await refresh.getRoomForRefresh(roomId: room.ref.roomId)).map((fresh) => fresh.broadcast.isLiveNow);
}
