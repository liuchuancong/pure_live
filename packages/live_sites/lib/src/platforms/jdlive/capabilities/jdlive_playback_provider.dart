import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_manifest.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// JD Live's playback: the qualities a broadcast's play answer offers and the
/// one line behind each.
///
/// The addresses carry no signature or expiry, so a line has no lease; the
/// qualities come from the play answer of the room read, or from a fresh one
/// when none is kept (see `JdliveSite._playable`). A broadcast that is
/// announced or over, one for JD's app only, and one without its address or
/// recording are errors that name the reason, never an empty list.
final class JdlivePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  JdlivePlaybackProvider({required this.site});

  /// The site this capability serves.
  final JdliveSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError(jdliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: jdliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality));
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError(jdliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: jdliveSiteId, message: '$error', cause: error));
    }
  }
}
