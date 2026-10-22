import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LOOK Live's playback: the HLS and FLV lines of the room answer its room
/// entry brought (or a fresh entry when none is kept).
///
/// The addresses are unsigned, so no line carries a lease. A room that is
/// not live, is banned, is watchable in the LOOK app only, is behind a
/// ticket, or is live without a usable address is an error that names the
/// reason, never an empty list.
final class LooklivePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  LooklivePlaybackProvider({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required String roomId}) async {
    try {
      return right(await site.qualitiesOf(roomId));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required String roomId, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(roomId, quality: quality));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }
}
