import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bigo rooms, refreshed: the reusable-token studio read, not an entry read with a fresh token.
final class BigoRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  BigoRoomRefresh({required this.site});

  /// The site this capability serves.
  final BigoSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(BigoRoomParser.room(await site.refresh(roomId)));
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError(bigoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bigoSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError(bigoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bigoSiteId, message: '$error', cause: error));
    }
  }
}
