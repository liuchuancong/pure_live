import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LOOK Live's one-bit status ask: the room answer (without its streams)
/// says live or not.
///
/// Live rooms that cannot be played here (app-only, ticketed) are live too;
/// a banned room is not live; an unknown `liveStatus` is a left, never an
/// invented offline.
final class LookliveStatusCheck implements LiveStatusCheck {
  /// Serves [site].
  LookliveStatusCheck({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, bool>> getLiveStatus({required LiveRoom room}) async {
    try {
      return right(await site.liveStatus(room.roomId));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }
}
