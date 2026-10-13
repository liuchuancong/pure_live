import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/converters/audience_number_converter.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'room_audience.freezed.dart';
part 'room_audience.g.dart';

/// A room's audience figures, each meaning exactly one thing.
///
/// All counts are `int?`: null = the source did not say, and a real zero
/// stays a zero — no sentinel strings (MODELS.md §3.5). [primaryMetric] says
/// which figure a list card leads with; it is the reading of the legacy v1
/// `watching` field, whose text is re-dispatched here at read time.
@freezed
abstract class RoomAudience with _$RoomAudience {
  /// Creates a RoomAudience with already-normalized fields.
  const factory RoomAudience({
    @AudienceNumberConverter() int? popularity,
    @AudienceNumberConverter() int? onlineViewers,
    @AudienceNumberConverter() int? totalViewers,
    LiveAudienceMetricType? primaryMetric,
  }) = _RoomAudience;

  const RoomAudience._();

  /// Deserializes a stored JSON record.
  factory RoomAudience.fromJson(Map<String, Object?> json) => _$RoomAudienceFromJson(json);

  /// A sparse refresh merge: an incoming null or unknown metric never erases
  /// a stored figure.
  RoomAudience mergedWith(RoomAudience incoming) {
    final metric = incoming.primaryMetric;
    return copyWith(
      popularity: incoming.popularity ?? popularity,
      onlineViewers: incoming.onlineViewers ?? onlineViewers,
      totalViewers: incoming.totalViewers ?? totalViewers,
      primaryMetric: metric != null && metric != LiveAudienceMetricType.unknown ? metric : primaryMetric,
    );
  }
}
