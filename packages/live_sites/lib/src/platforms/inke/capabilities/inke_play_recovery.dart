import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Inke's recovery ask: a newly signed `now_publish` answer, never the room
/// entry's kept one, whatever the room's last known state — the held
/// `wsABStime` URLs are the ones that failed, and an anchor the entry saw
/// offline may be live again. An anchor the app says is not live says so
/// instead of replaying a dead address.
final class InkePlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  InkePlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final InkePlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.refetchLines(room: room, quality: quality);
}
