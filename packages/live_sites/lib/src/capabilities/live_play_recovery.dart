import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

/// Fresh lines after a failure, for platforms whose URLs die with the
/// session that resolved them.
///
/// A mid-stream failure on these platforms is not retriable by replaying
/// the held URL — the address must be asked for again. This capability is
/// that ask; the platform decides what a fresh resolution costs (a signed
/// request, a room re-entry) and returns lines that are guaranteed new.
/// Platforms whose lines outlive playback never implement it and recovery
/// replays the held URL instead.
abstract interface class LivePlayRecovery implements LiveSiteCapability {
  /// Fresh lines for [room] at [quality] after a failure. A left names why
  /// they could not be re-resolved.
  Future<Either<LiveSiteError, List<LivePlayLine>>> refetchLines({required LiveRoom room, LivePlayQuality? quality});
}
