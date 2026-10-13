/// The lifecycle state of a site instance.
enum LiveSiteStatus {
  /// Constructed but not yet initialized.
  uninitialized,

  /// Initialization is in progress.
  initializing,

  /// Ready for use.
  ready,

  /// Usable, but with some features known to be degraded.
  degraded,

  /// Not currently usable (for example, a transient outage).
  unavailable,

  /// Disposed; resources released and not reusable.
  disposed,
}

/// Current runtime status, distinct from the immutable manifest.
class LiveSiteRuntimeInfo {
  /// Creates runtime info for [status], with an optional human [message] and
  /// the time it was last checked.
  const new({required this.status, this.message, this.lastCheckedAt});

  /// The site's current lifecycle state.
  final LiveSiteStatus status;

  /// A diagnostic message about the state, when there is one.
  final String? message;

  /// When the status was last observed.
  final DateTime? lastCheckedAt;
}
