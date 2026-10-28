import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kilakila's refresh reads: the profile alone for a refresh; the recorder
/// takes the entered room (profile plus `roomInfo`) through the site's detail
/// read.
final class KilakilaRoomRefresh implements LiveRoomRefresh {
  /// Serves [site].
  KilakilaRoomRefresh({required this.site});

  /// The site this capability serves.
  final KilakilaSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRefresh({required String roomId}) async {
    try {
      return right(KilakilaRoomParser.profileDetail(await site.profile(roomId)));
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError(kilakilaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kilakilaSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoomForRecording({required String roomId}) async {
    try {
      return right(await site.detail(roomId));
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError(kilakilaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kilakilaSiteId, message: '$error', cause: error));
    }
  }
}
