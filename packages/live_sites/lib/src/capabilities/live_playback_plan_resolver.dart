import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/live_playback_plan/live_playback_plan.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

/// The play resolution with its confirmations: what the platform actually
/// served, not only what was asked.
///
/// `LivePlaybackProvider.getLines` answers the simple ask — the lines behind
/// a quality. This answers the asks around it: whether the served quality
/// was the requested one (an anonymous request can be silently downgraded),
/// and where playback begins (a carousel's current programme starts
/// part-way in). Platforms whose answers carry none of this never implement
/// this and stay with `getLines`.
abstract interface class LivePlaybackPlanResolver implements LiveSiteCapability {
  /// The plan for [room] at [quality] (the default quality when null). A
  /// left names why the plan could not be read.
  Future<Either<LiveSiteError, LivePlaybackPlan>> resolvePlan({required LiveRoom room, LivePlayQuality? quality});
}
