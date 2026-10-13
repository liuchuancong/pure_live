/// What a room's audience number means. Stored by name in room JSON.
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
