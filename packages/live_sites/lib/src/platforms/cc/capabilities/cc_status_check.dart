import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CC's one-bit status ask, read the way the recorder reads it: the two
/// chained requests, and on a channel-less anchor nothing more — the
/// 8 s existence probe of a follow refresh must not run on a timer.
/// A "【重播】" rebroadcast is a replay, not live.
final class CcStatusCheck implements LiveStatusCheck {
  /// Serves [refresh] (the recording-depth read it shares).
  CcStatusCheck({required this.refresh});

  /// The refresh this read shares.
  final LiveRoomRefresh refresh;

  @override
  Future<Either<LiveSiteError, bool>> getLiveStatus({required LiveRoom room}) async =>
      (await refresh.getRoomForRecording(roomId: room.ref.roomId)).map((fresh) => fresh.broadcast.isLiveNow);
}
