// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_audience_metric_type/live_audience_metric_type.dart';
import 'package:meta/meta.dart';

/// The audience figures a room reports, as the platform wrote them.
///
/// A value is the platform's own text (`'5.6万'`, `'1234'`); `'0'` in
/// [watching] is the old default and not a measurement. What the main number
/// means is given by [metricType], or by the platform's usual one when it is
/// null or unknown (see `LiveRoom.effectiveAudienceMetricType`, which supplies
/// the platform). This is pure data; the ranking and fallback logic lives on
/// the room, which knows its platform and its `LiveAudiencePlatformCapability`.
@immutable
final class LiveAudience {
  /// Creates an audience snapshot.
  const LiveAudience({
    this.watching = '0',
    this.metricType,
    this.popularity = '',
    this.onlineViewers = '',
    this.totalViewers = '',
  });

  /// The single audience field of older records and backups.
  final String watching;

  /// What the platform's main audience number means; null when not given.
  final LiveAudienceMetricType? metricType;

  /// Popularity or heat; not a head count.
  final String popularity;

  /// Concurrent viewers, when the platform exposes an explicit value.
  final String onlineViewers;

  /// Cumulative viewers of the current session.
  final String totalViewers;

  /// This snapshot with only the fields [incoming] actually reported kept from
  /// it; an empty incoming value falls back to the stored one, so a sparse
  /// refresh never erases an audience figure already known.
  LiveAudience mergedWith(LiveAudience incoming) {
    String prefer(String next, String current) => next.trim().isEmpty ? current : next;
    final given = incoming.metricType;
    return LiveAudience(
      watching: prefer(incoming.watching, watching),
      metricType: given != null && given != LiveAudienceMetricType.unknown ? given : metricType,
      popularity: prefer(incoming.popularity, popularity),
      onlineViewers: prefer(incoming.onlineViewers, onlineViewers),
      totalViewers: prefer(incoming.totalViewers, totalViewers),
    );
  }

  @override
  String toString() =>
      'LiveAudience(watching: $watching, popularity: $popularity, online: $onlineViewers, total: $totalViewers)';
}
