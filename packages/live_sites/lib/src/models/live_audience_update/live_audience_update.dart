// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_audience_metric_kind/live_audience_metric_kind.dart';
import 'package:meta/meta.dart';

/// A typed audience update, so heat, concurrent and cumulative viewers are never
/// relabelled as the same number.
@immutable
final class LiveAudienceUpdate {
  /// Creates an update.
  const LiveAudienceUpdate({required this.kind, required this.value});

  /// What [value] means.
  final LiveAudienceMetricKind kind;

  /// The number.
  final int value;
}
