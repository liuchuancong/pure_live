import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_room_provider.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's refresh reads: the WBI-signed metadata request that carries the
/// room's state, title, cover and figures, without the danmaku handshake a
/// first visit pays for.
///
/// The recorder read is the same request: everything `getQualities` and
/// `getLines` need (the canonical long id included) comes from it.
final class BilibiliRoomRefresh implements LiveRoomRefresh {
  /// Serves [site]; [rooms] is the read path this capability shares.
  BilibiliRoomRefresh({required this.site, required this.rooms});

  /// The site this capability serves.
  final BilibiliSite site;

  /// The room provider whose metadata read this capability exposes.
  final BilibiliRoomProvider rooms;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await rooms.refresh(roomId));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      getRoomForRefresh(roomId: roomId);
}
