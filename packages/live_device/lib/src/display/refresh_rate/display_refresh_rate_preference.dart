/// Outcome of submitting a preferred refresh rate to the display backend.
///
/// The backend distinguishes "this platform has no such request path" from a
/// request that could not be carried out right now, so callers can decide
/// whether to retry, hide the control, or accept the current rate.
enum DisplayRefreshRatePreference {
  /// The request reached the platform backend.
  ///
  /// This is a submission, not a promise: the OS may still keep a lower rate
  /// for thermal or power reasons.
  submitted,

  /// The active backend has no API path for this request.
  unsupported,

  /// The request is supported in principle but has no usable target right now.
  unavailable,

  /// The request could not be carried out.
  ///
  /// A request that was replaced by a newer one is reported here as well.
  failed,
}
