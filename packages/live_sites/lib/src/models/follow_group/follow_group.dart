/// Where the follow page lists a room (live, replay and offline tabs).
enum FollowGroup {
  /// Broadcasting now, restricted or not.
  live,

  /// A replay that can be played.
  replay,

  /// Everything else: offline, carousel, banned, pending, and a replay marked
  /// `LiveRestriction.unplayable`.
  offline,
}
