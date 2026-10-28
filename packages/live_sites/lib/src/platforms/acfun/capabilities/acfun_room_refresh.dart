import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// AcFun's refresh reads: `live/info` alone for a refresh, the same read plus
/// `startPlay` for the recorder (whose stream handle, danmaku arguments and
/// restriction come from it).
final class AcfunRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  AcfunRoomRefresh({required this.site});

  /// The site this capability serves.
  final AcfunSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(await site.info(roomId));
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError(acfunSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: acfunSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError(acfunSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: acfunSiteId, message: '$error', cause: error));
    }
  }
}
