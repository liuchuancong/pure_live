/// What kind of content a playback session carries.
///
/// The distinction is not cosmetic: live content cannot be seeked past the
/// live edge, its lease expires, and returning to it after a detour means
/// re-syncing with the broadcast clock. Recorded content keeps a position
/// worth remembering. The orchestrator switches on this when one replaces
/// the other.
enum ContentType {
  /// A real-time broadcast. Positions are wall-clock, lines carry leases.
  live,

  /// A pre-recorded video. Positions are stable and worth restoring.
  recorded,
}
