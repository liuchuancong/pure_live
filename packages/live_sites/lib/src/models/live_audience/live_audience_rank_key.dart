// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// A sortable audience key for rooms whose platforms use different scales. In
/// concurrent-viewer mode an explicit concurrent value ranks ahead of a pending
/// one, and a pending supported room ahead of a heat or cumulative fallback.
@immutable
final class LiveAudienceRankKey {
  /// Creates a key.
  const LiveAudienceRankKey({required this.metricPriority, required this.value});

  /// Higher ranks first: 3 explicit concurrent, 2 pending concurrent, 1 a
  /// native value, 0 nothing.
  final int metricPriority;

  /// The number within the tier.
  final int value;
}
