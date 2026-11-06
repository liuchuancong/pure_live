import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugoulive's one-bit status ask, read through the same refresh the follow and
/// history lists use.
///
/// The room info names a live session or `liveType` -1; a room with neither
/// is shown as unknown and has no answer here — a left, never an invented
/// offline (a chat limit alone keeps a room live).
final class KugouliveStatusCheck implements LiveStatusCheck {
  /// Serves [refresh].
  KugouliveStatusCheck({required this.refresh});

  /// The refresh read this capability shares.
  final LiveRoomRefresh refresh;

  @override
  Future<Either<LiveSiteError, bool>> getLiveStatus({required LiveRoom room}) async =>
      (await refresh.getRoomForRefresh(roomId: room.ref.roomId)).flatMap(
        (fresh) => fresh.broadcast.liveStatus == LiveStatus.unknown
            ? left(
                LiveSiteError.parse(
                  siteId: kugouliveSiteId,
                  message: 'room ${room.ref.roomId}: neither offline nor a live session',
                ),
              )
            : right(fresh.broadcast.isLiveNow),
      );
}
