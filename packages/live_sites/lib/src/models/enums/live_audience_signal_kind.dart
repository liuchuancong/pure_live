/// The metric kind of one realtime audience update carried by a message.
///
/// Distinct from `LiveAudienceMetricType` (a record's primary metric): this
/// classifies a signal inside the danmaku stream (MODELS.md §2.9).
enum LiveAudienceSignalKind {
  /// Popularity or heat.
  popularity,

  /// Concurrent viewers.
  onlineViewers,

  /// Cumulative viewers.
  totalViewers,
}
