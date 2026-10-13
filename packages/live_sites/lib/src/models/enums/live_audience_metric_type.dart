/// What a room's primary audience number means.
///
/// This is `RoomAudience.primaryMetric`: which of the audience figures a list
/// card leads with, and the label basis for cross-platform sorting.
enum LiveAudienceMetricType {
  /// Platform popularity or heat; not a head count.
  popularity,

  /// Concurrent viewers.
  onlineViewers,

  /// Cumulative viewers of the current session.
  totalViewers,

  /// Followers of the streamer.
  followers,

  /// Not known.
  unknown,
}
