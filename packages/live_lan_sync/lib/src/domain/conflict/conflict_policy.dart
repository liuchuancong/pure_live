/// How concurrent modifications are settled.
///
/// These are strategy *options*, not unconditional behaviours: a scope's
/// adapter declares which of them it can actually honour, and the safe
/// default across the engine is [manual] — report the conflict, never pick
/// a winner silently.
enum ConflictPolicy {
  /// Hand the conflict to the host's UI and wait for a decision.
  manual,

  /// Keep this device's version. Only sane for values where losing the
  /// remote edit is acceptable to the user.
  preferLocal,

  /// Keep the peer's version.
  preferRemote,

  /// Ask the scope's adapter to merge both versions.
  merge,

  /// Keep both versions as distinct copies for the user to sort out.
  keepBoth,
}
