import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kilakila/capabilities/kilakila_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// KilaKila's recovery ask: the anchor is entered again (profile, then the
/// current broadcast's `getRoomInfo`), bypassing the held stream data — the
/// pull URLs are signed per broadcast, and the anchor may have gone live
/// again on a new one.
final class KilakilaPlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  KilakilaPlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final KilakilaPlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.refetchLines(room: room, quality: quality);
}
