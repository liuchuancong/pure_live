/// The lifecycle state of a room, stored by index for 3.x JSON
/// compatibility — the numeric order is part of the persistence contract
/// and must not change.
enum LiveStatus {
  /// Streaming right now.
  live,

  /// Not streaming.
  offline,

  /// Showing a replay instead of a live stream.
  replay,

  /// State unknown (fetch failed, never fetched).
  unknown,

  /// The room is banned by the platform.
  banned,

  /// The room plays a platform carousel.
  carousel,
}

/// Platform-imposed viewing restrictions, stored and read by name for 3.x
/// JSON compatibility: the names are 3.x's own (`needsLogin`, `password`, …),
/// so a room 3.x persisted reads back unchanged.
///
/// A restriction the platform states and one this client merely assumes are
/// different facts, which is why the enum carries `none` beside a null
/// restriction: null is "the answer did not say".
enum LiveRestriction {
  /// No restriction at all — the platform said so.
  none,

  /// Only signed-in viewers can watch.
  needsLogin,

  /// A paid broadcast or ticket.
  paid,

  /// Only the streamer's subscribers or members.
  subscribersOnly,

  /// Private or friends-only.
  private,

  /// Only in the platform's own app.
  appOnly,

  /// Not available in the viewer's region.
  regionBlocked,

  /// Protected by a room password.
  password,

  /// Adult content behind the platform's age check.
  adult,

  /// The platform says the room is on or has a replay, but gives this client
  /// no stream (a replay without an address, for example).
  unplayable;

  /// Parses the name a room was stored under; an unknown name (one a later
  /// build added) reads as no restriction rather than breaking the reader.
  static LiveRestriction? tryParse(String name) => values.asNameMap()[name];
}
