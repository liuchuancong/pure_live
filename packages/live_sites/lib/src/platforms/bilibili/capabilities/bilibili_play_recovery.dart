import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's recovery ask: `getRoomPlayInfo` read again for the room's
/// canonical long id — the addresses are handed out per answer and die with
/// the session that got them, so a fresh read is the only re-ask there is.
/// A carousel without a stream for this client still falls back to its
/// rotation video, judged from the fresh answer alone.
final class BilibiliPlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  BilibiliPlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final BilibiliPlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.refetchLines(room: room, quality: quality);
}
