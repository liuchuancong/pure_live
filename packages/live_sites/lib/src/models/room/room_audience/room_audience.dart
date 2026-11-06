// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'room_audience.g.dart';

/// A room's audience figures, each meaning exactly one thing.
///
/// All counts are `int?`: null = the source did not say, and a real zero
/// stays a zero — no sentinel strings (MODELS.md §3.5). [primaryMetric] says
/// which figure a list card leads with; it is the reading of the legacy v1
/// `watching` field, whose text is re-dispatched here at read time.
abstract class RoomAudience implements Built<RoomAudience, RoomAudienceBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory RoomAudience([void Function(RoomAudienceBuilder)? updates]) = _$RoomAudience;

  /// Creates a RoomAudience with already-normalized fields.
  /// Creates a RoomAudience with already-normalized fields.
  factory RoomAudience.of({
    int? popularity,
    int? onlineViewers,
    int? totalViewers,
    LiveAudienceMetricType? primaryMetric,
  }) => RoomAudience(
    (b) => b
      ..popularity = popularity
      ..onlineViewers = onlineViewers
      ..totalViewers = totalViewers
      ..primaryMetric = primaryMetric,
  );

  RoomAudience._();

  /// Deserializes a stored JSON record.
  factory RoomAudience.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(RoomAudience.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<RoomAudience> get serializer => _$roomAudienceSerializer;

  /// The platform's heat figure.
  int? get popularity;

  /// Concurrent unique viewers, when the platform says so.
  int? get onlineViewers;

  /// Cumulative viewers of this session.
  int? get totalViewers;

  /// Which figure a list card leads with.
  LiveAudienceMetricType? get primaryMetric;

  /// The figure a card leads with when the viewer asks for [lead], falling
  /// back to the others so a source without it still shows one: concurrent,
  /// heat, cumulative for [LiveAudienceMetricType.onlineViewers]; cumulative,
  /// heat, concurrent for [LiveAudienceMetricType.totalViewers]; heat,
  /// concurrent, cumulative for [LiveAudienceMetricType.popularity]. Any
  /// other [lead] (null: the viewer left it to the platform) follows
  /// [primaryMetric] the same way. Null when there is no figure at all.
  int? leadingFigure(LiveAudienceMetricType? lead) {
    final metric = switch (lead) {
      LiveAudienceMetricType.onlineViewers ||
      LiveAudienceMetricType.popularity ||
      LiveAudienceMetricType.totalViewers => lead,
      _ => primaryMetric,
    };
    return switch (metric) {
      LiveAudienceMetricType.onlineViewers => onlineViewers ?? popularity ?? totalViewers,
      LiveAudienceMetricType.totalViewers => totalViewers ?? popularity ?? onlineViewers,
      _ => popularity ?? onlineViewers ?? totalViewers,
    };
  }

  /// A sparse refresh merge: an incoming null or unknown metric never erases
  /// a stored figure.
  ///
  /// With [hasTransientPopularityDrop] (the source's
  /// `LiveAudienceCapability.hasTransientPopularityDrop`), an incoming
  /// popularity of 1 or less against a stored one of at least 1000 is that
  /// glitch, not the room emptying, and the stored figure stays; a later
  /// plausible figure is taken as usual.
  RoomAudience mergedWith(RoomAudience incoming, {bool hasTransientPopularityDrop = false}) {
    final metric = incoming.primaryMetric;
    final stored = popularity;
    final fresh = incoming.popularity;
    final collapsed = hasTransientPopularityDrop && stored != null && fresh != null && stored >= 1000 && fresh <= 1;
    return rebuild(
      (b) => b
        ..popularity = collapsed ? stored : (fresh ?? stored)
        ..onlineViewers = incoming.onlineViewers ?? onlineViewers
        ..totalViewers = incoming.totalViewers ?? totalViewers
        ..primaryMetric = metric != null && metric != LiveAudienceMetricType.unknown ? metric : primaryMetric,
    );
  }
}
