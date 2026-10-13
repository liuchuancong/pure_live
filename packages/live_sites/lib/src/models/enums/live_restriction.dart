/// What keeps a room from being played directly by the current viewer.
///
/// [none] means the source explicitly said "no restriction"; a null field
/// means the source said nothing at all.
enum LiveRestriction {
  /// No restriction reported.
  none,

  /// Watching requires a signed-in account.
  needsLogin,

  /// Watching requires payment.
  paid,

  /// Watching requires a paid membership of the streamer.
  subscribersOnly,

  /// The room is private.
  private,

  /// Watching requires the platform's own app.
  appOnly,

  /// The room is not available in the current region.
  regionBlocked,

  /// The room is password protected.
  password,

  /// The room is age-restricted adult content.
  adult,

  /// Unplayable for an unspecified reason.
  unplayable;

  /// The restriction named [name], or [none] for anything else.
  static LiveRestriction fromName(Object? name) => values.asNameMap()[name] ?? none;
}
