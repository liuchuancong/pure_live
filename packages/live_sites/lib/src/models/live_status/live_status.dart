/// A room's broadcast state. Stored by **index** in room JSON, so the order
/// must never change; new states are only appended.
enum LiveStatus {
  /// Broadcasting now.
  live,

  /// Not broadcasting.
  offline,

  /// Playing a recording or replay: playable, but not a live broadcast. A
  /// replay the platform gives no stream for carries a `unplayable`
  /// restriction.
  replay,

  /// Not known (no platform evidence, or the last request failed).
  unknown,

  /// Banned or closed by the platform.
  banned,

  /// Looping old videos while the streamer is off (Bilibili's carousel).
  /// Grouped with offline and not playable.
  carousel,
}
