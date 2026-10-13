/// Why a room that is on air cannot simply be played. Lists and the room page
/// still show the room as live and mark the kind; playback explains it.
///
/// Stored by **name** in room JSON, so kinds can be added in any position; a
/// name this build does not know reads as [none].
enum LiveRestriction {
  /// No restriction.
  none,

  /// Only signed-in viewers can watch (playback fails with `NeedsLogin`).
  needsLogin,

  /// A paid broadcast or ticket.
  paid,

  /// Only the streamer's subscribers or members.
  subscribersOnly,

  /// Private or friends-only.
  private,

  /// Only in the platform's own app.
  appOnly,

  /// Not available in the viewer's region (playback fails with `RegionBlocked`).
  regionBlocked,

  /// Protected by a room password.
  password,

  /// Adult content behind the platform's age check.
  adult,

  /// The platform says the room is on or has a replay, but gives this client
  /// no stream (for example a replay without an address).
  unplayable;

  /// The kind stored as [name]; an unknown name (a kind added by a later
  /// build) is [none].
  static LiveRestriction fromName(Object? name) => values.asNameMap()[name] ?? none;
}
