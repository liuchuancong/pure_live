import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/huya/capabilities/huya_playback_provider.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Huya's recovery ask: the room's `profileRoom` read again — past the short
/// window one open's entry, quality list and line signing share it in — and
/// every line signed with a token fetched now. Nothing the entry kept is
/// replayed: a fresh read is a fresh signing throughout.
final class HuyaPlayRecovery implements LivePlayRecovery {
  /// Serves [playback].
  HuyaPlayRecovery({required this.playback});

  /// The playback read whose fresh path this capability exposes.
  final HuyaPlaybackProvider playback;

  @override
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality}) =>
      playback.refetchLines(room: room, quality: quality);
}
