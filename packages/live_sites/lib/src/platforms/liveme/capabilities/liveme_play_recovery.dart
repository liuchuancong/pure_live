import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/liveme/capabilities/liveme_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LiveMe's recovery ask: the short id's current broadcast and its signed
/// `queryinfosimple` again (two requests), never the stream data kept from
/// the room entry — the anchor may have started a new broadcast. One that
/// ended meanwhile says so instead of replaying a dead address.
final class LivemePlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  LivemePlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final LivemePlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.refetchLines(room: room, quality: quality);
}
