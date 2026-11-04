// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';

part 'live_playback_plan.g.dart';

/// What a play resolution actually handed over: the lines plus the facts a
/// plain line list cannot carry.
///
/// [appliedQuality] is the quality the platform says it served — the ask and
/// the answer differ when an anonymous request is silently downgraded, and
/// [qualityUnconfirmed] marks an answer that does not say. [start] is the
/// playback offset a source declares (a carousel's current programme begins
/// part-way in); null is live-from-now.
abstract class LivePlaybackPlan implements Built<LivePlaybackPlan, LivePlaybackPlanBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LivePlaybackPlan([void Function(LivePlaybackPlanBuilder)? updates]) = _$LivePlaybackPlan;

  /// Creates a LivePlaybackPlan with already-normalized fields.
  factory LivePlaybackPlan.of({
    required List<LivePlayLine> lines,
    LivePlayQuality? appliedQuality,
    bool qualityUnconfirmed = false,
    Duration? start,
  }) => LivePlaybackPlan(
    (b) => b
      ..lines.replace(lines)
      ..appliedQuality = appliedQuality?.toBuilder()
      ..qualityUnconfirmed = qualityUnconfirmed
      ..start = start,
  );

  LivePlaybackPlan._();

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LivePlaybackPlanBuilder b) => b..qualityUnconfirmed = false;

  /// The playable lines, in the platform's order.
  BuiltList<LivePlayLine> get lines;

  /// The quality the platform says it served, when it says so.
  LivePlayQuality? get appliedQuality;

  /// The answer does not name the quality it served.
  bool get qualityUnconfirmed;

  /// Where playback begins, when the source declares an offset.
  Duration? get start;
}

/// Whether two entries name the same tier: the platform's own id when both
/// carry one, else their label.
bool isSamePlayTier(LivePlayQuality a, LivePlayQuality b) =>
    a.qualityId != null && b.qualityId != null ? a.qualityId == b.qualityId : a.label == b.label;

/// The tier a room should be *shown* as playing after [plan] answered a
/// request for [requested], or null when the platform said nothing.
///
/// The ask and the answer differ on several platforms: an anonymous request
/// is quietly downgraded, and a streamer can change profile mid-broadcast.
/// Naming what was asked for over a picture that is not it is a lie the
/// viewer can only catch by squinting at the pixels. A served tier the list
/// already holds is returned as that entry; one the list never offered takes
/// [requested]'s place in the caller's list — the reference's C01.4 rule — so
/// the picker keeps exactly one entry per ask rather than growing a tier the
/// viewer cannot ask for again.
LivePlayQuality? resolveServedPlayQuality({
  required LivePlaybackPlan plan,
  required List<LivePlayQuality> qualities,
  required LivePlayQuality requested,
}) {
  if (plan.qualityUnconfirmed) return null;
  final applied = plan.appliedQuality;
  if (applied == null) return null;
  for (final quality in qualities) {
    if (isSamePlayTier(quality, applied)) return quality;
  }
  return isSamePlayTier(requested, applied) ? requested : applied;
}
