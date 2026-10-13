// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor
/// The lifecycle state of a site instance.
enum LiveSiteStatus {
  /// Constructed, not yet initialized.
  uninitialized,

  /// `initialize` is running.
  initializing,

  /// Ready to serve capabilities.
  ready,

  /// Serving with reduced capability (a resource failed but the site
  /// remains usable).
  degraded,

  /// Currently unusable; a transient condition, not a disposal.
  unavailable,

  /// Disposed; the instance is not reusable.
  disposed,
}

/// The current runtime status of a site instance.
///
/// Deliberately coarse: runtime status never replaces operation-level error
/// handling, and a transient API failure must not mark every capability
/// unavailable.
class LiveSiteRuntimeInfo {
  /// Builds a status snapshot.
  const LiveSiteRuntimeInfo({required this.status, this.message, this.lastCheckedAt});

  /// The lifecycle state.
  final LiveSiteStatus status;

  /// A diagnostic message, when the state needs one.
  final String? message;

  /// When the status was last refreshed, UTC.
  final DateTime? lastCheckedAt;
}
