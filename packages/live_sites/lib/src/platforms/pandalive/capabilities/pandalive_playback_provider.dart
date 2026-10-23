import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_manifest.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// PandaTV's playback: the IVS variants of the broadcast, one quality per
/// video variant, the source rendition (原画) first.
///
/// Each line is a signed variant playlist whose token is single use and
/// which the platform refuses once its lease has run out, so every line
/// carries the lease of its issue and says that playing needs the
/// re-resolve. A broadcast that is not live, one that cannot be played and
/// one without a usable variant are errors that name the reason, never an
/// empty list.
final class PandalivePlaybackProvider implements LivePlaybackProvider {
  /// Serves [site].
  PandalivePlaybackProvider({required this.site});

  /// The site this capability serves.
  final PandaliveSite site;

  @override
  Future<Either<LiveSiteError, List<LivePlayQuality>>> getQualities({required LiveRoom room}) async {
    try {
      return right(await site.qualitiesOf(room.roomId));
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(pandaliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: pandaliveSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> getLines({required LiveRoom room, LivePlayQuality? quality}) async {
    try {
      return right(await site.linesOf(room.roomId, quality: quality));
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(pandaliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: pandaliveSiteId, message: '$error', cause: error));
    }
  }
}
