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

/// Huya's recovery ask: every `getLines` call fetches and signs its own
/// tokens (nothing is cached), so the recovery read is the playback read.
final class HuyaPlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  HuyaPlayRecovery({required this.playback});

  /// The playback read that re-signs every line.
  final LivePlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.getLines(room: room, quality: quality);
}
