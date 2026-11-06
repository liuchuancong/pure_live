import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_manifest.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Jdlive's one-bit status ask: the play answer alone, the one request the
/// follow refresh also makes.
///
/// It reads the broadcast's own state rather than the refreshed room's,
/// because a paused broadcast and an unreadable status both show as unknown
/// there: paused says the stream is unavailable, an unknown status that the
/// answer changed — a left either way, never an invented offline. An
/// app-only broadcast is live.
final class JdliveStatusCheck implements LiveStatusCheck {
  /// Serves [site].
  JdliveStatusCheck({required this.site});

  /// The site this capability serves.
  final JdliveSite site;

  @override
  Future<Either<LiveSiteError, bool>> getLiveStatus({required LiveRoom room}) async {
    try {
      return right(await site.liveStatus(room.ref.roomId));
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError(jdliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: jdliveSiteId, message: '$error', cause: error));
    }
  }
}
