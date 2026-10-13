/// The broadcast state of a room or anchor.
///
/// Persistence stores the name string, never the index: values may only be
/// inserted before [unknown] (MODELS.md §2.1).
enum LiveStatus {
  /// On air.
  live,

  /// A recording or replay: playable, but not a live broadcast.
  replay,

  /// A carousel: the streamer is off and the platform loops past content.
  carousel,

  /// Not broadcasting.
  offline,

  /// Cut off or banned by the platform.
  banned,

  /// Unknown: the source did not report a state, or it is unresolved.
  unknown,
}
