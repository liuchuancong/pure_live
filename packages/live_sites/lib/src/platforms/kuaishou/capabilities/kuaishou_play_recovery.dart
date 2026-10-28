import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kuaishou/capabilities/kuaishou_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kuaishou's recovery ask: Kuaishou re-reads the room page on every playback read, so recovery is that read.
final class KuaishouPlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  KuaishouPlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final KuaishouPlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({
    required LiveRoom room,
    LivePlayQuality? quality,
  }) => playback.refetchLines(room: room, quality: quality);
}
