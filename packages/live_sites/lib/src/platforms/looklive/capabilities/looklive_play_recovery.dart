import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/capabilities/looklive_playback_provider.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LOOK Live's recovery ask: a fresh room answer (`room/get/v3`), whose
/// streams replace the entry the held lines came from.
///
/// The addresses themselves do not expire, but a broadcast that has moved
/// on answers new ones; a room that can no longer be played says why.
final class LooklivePlayRecovery implements LivePlayRecovery {
  /// Serves [playback]'s site.
  LooklivePlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final LooklivePlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({
    required LiveRoom room,
    LivePlayQuality? quality,
  }) async {
    try {
      return right(await playback.site.refetchLines(room, quality: quality));
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
  }
}
