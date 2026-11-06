import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's recovery ask: the play metadata asked for again (the rate `-1`
/// `getH5PlayV1` — its CDN set is the room's and refreshes it in place) and
/// every line signed with a play request sent now. No answer already handed
/// out is replayed.
final class DouyuPlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  DouyuPlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final DouyuPlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.refetchLines(room: room, quality: quality);
}
