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

  /// A sparse refresh merge: an incoming null or unknown metric never erases
  /// a stored figure.
  RoomAudience mergedWith(RoomAudience incoming) {
    final metric = incoming.primaryMetric;
    return rebuild(
      (b) => b
        ..popularity = incoming.popularity ?? popularity
        ..onlineViewers = incoming.onlineViewers ?? onlineViewers
        ..totalViewers = incoming.totalViewers ?? totalViewers
        ..primaryMetric = metric != null && metric != LiveAudienceMetricType.unknown ? metric : primaryMetric,
    );
  }
}
