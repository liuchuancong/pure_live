import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/capabilities/kugoulive_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugou Live's recovery ask: the room is entered again (`getEnterRoomInfo`,
/// then `streamaddr`), bypassing the variants room entry kept — the media
/// URLs are signed per answer (`txSecret`/`txTime`), and the held ones are
/// what failed.
final class KugoulivePlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  KugoulivePlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final KugoulivePlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.refetchLines(room: room, quality: quality);
}
