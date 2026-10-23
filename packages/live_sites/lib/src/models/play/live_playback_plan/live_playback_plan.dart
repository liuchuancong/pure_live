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
