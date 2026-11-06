import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CC rooms, refreshed: 3.x's requests without a room page.
///
/// A refresh of an anchor without a live channel asks the existence check
/// (9-7, one request more): CC saying the id is no account is not-found, a
/// failed or slow check leaves the room marked offline. The recorder's
/// strict read skips that check — a room on air carries its tier list,
/// anything else is offline.
final class CcRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  CcRoomRefresh({required this.site});

  /// The site this capability serves.
  final CcSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) =>
      _run(() => site.refreshRoom(roomId));

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) =>
      _run(() => site.statusRoom(roomId));

  Future<Either<LiveSiteError, T>> _run<T>(Future<T> Function() work) async {
    try {
      return right(await work());
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
    }
  }
}
