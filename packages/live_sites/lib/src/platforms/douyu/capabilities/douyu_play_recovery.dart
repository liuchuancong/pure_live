import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's recovery ask: every `getLines` call asks the play API again with
/// a fresh signature, so the recovery read is the playback read.
final class DouyuPlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  DouyuPlayRecovery({required this.playback});

  /// The playback read that re-asks every CDN.
  final LivePlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.getLines(room: room, quality: quality);
}
