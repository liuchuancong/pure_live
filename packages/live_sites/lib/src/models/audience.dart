import 'package:meta/meta.dart';

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
@immutable
final class AudienceMetric {
  /// A reading of [value] viewers under [type].
  const new({required this.type, required this.value});

  /// Which口径 this number belongs to.
  final AudienceMetricType type;

  /// The reading itself.
  final int value;
}
