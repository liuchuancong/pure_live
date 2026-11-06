import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/jdlive/capabilities/jdlive_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// JD Live's recovery ask: a fresh play answer and, for a live broadcast,
/// its playlist check, bypassing the answer kept from the room read. The
/// addresses are unsigned, so this is about the broadcast's state, not a
/// token: one that paused or ended meanwhile says so instead of replaying a
/// dead address.
final class JdlivePlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  JdlivePlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final JdlivePlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.refetchLines(room: room, quality: quality);
}
