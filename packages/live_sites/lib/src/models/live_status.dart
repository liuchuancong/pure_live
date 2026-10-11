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

/// Platform-imposed viewing restrictions, stored by name for 3.x JSON
/// compatibility.
enum LiveRestriction {
  /// Login required before the stream plays.
  loginRequired('login_required'),

  /// Region blocked.
  regionBlocked('region_blocked');

  new(this.jsonName);

  /// The name used in 3.x-compatible JSON.
  final String jsonName;

  /// Parses the JSON name; unknown names fall back to null rather than
  /// throwing — new platform values must not break old clients.
  static LiveRestriction? tryParse(String name) => switch (name) {
    'login_required' => loginRequired,
    'region_blocked' => regionBlocked,
    _ => null,
  };
}
