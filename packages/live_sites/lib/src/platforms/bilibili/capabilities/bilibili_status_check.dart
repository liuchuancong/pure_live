import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_room_provider.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's one-bit status ask (`room/v1/Room/get_info`): the follow and
/// history lists check rooms with it instead of paying for a full detail.
final class BilibiliStatusCheck implements LiveStatusCheck {
  /// Serves [site]; [rooms] is the read path this capability shares.
  BilibiliStatusCheck({required this.site, required this.rooms});

  /// The site this capability serves.
  final BilibiliSite site;

  /// The room provider whose status read this capability exposes.
  final BilibiliRoomProvider rooms;

  @override
  Future<Either<LiveSiteError, bool>> getLiveStatus({required LiveRoom room}) async {
    try {
      return right(await rooms.liveStatus(room.ref.roomId));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }
}
