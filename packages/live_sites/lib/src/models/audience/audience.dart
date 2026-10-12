import 'package:equatable/equatable.dart';

/// Audience readings, separated from the room status because they travel on
/// their own: a danmaku session pushes them, a status refresh returns them,
/// and the UI shows them without caring which of the two delivered one.
///
/// The metric *type* is load-bearing. Platforms disagree on what they count
/// — seats watching, a popularity score that may be inflated, cumulative
/// unique viewers — and adding two different units together is a bug that
/// looks like a UI glitch: a room with 1.2M popularity and 12 viewers would
/// display "1,200,012 watching". Every reading therefore carries its unit,
/// and a consumer that only wants one kind filters by it.
/// What a platform's audience number counts.
enum AudienceMetricType {
  /// Seats currently watching (server-confirmed).
  watching,

  /// Popularity score (may be inflated by the platform).
  popularity,

  /// Cumulative unique viewers.
  onlineViewers,
}

/// One audience reading with its [type].
final class AudienceMetric extends Equatable {
  /// A reading of [value] viewers under [type].
  const new({required this.type, required this.value});

  /// Which instrument produced this number.
  final AudienceMetricType type;

  /// The reading itself.
  final int value;

  /// Identity is the pair: two readings of the same kind with the same value
  /// are the same reading, which is what lets a stream of updates be
  /// de-duplicated by value.
  @override
  List<Object?> get props => [type, value];
}
