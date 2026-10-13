/// A normalized, expected failure in a live-site operation.
///
/// Adapters return these at the business boundary (wrapped in an `Either`) so
/// a caller can tell "room not found" from "network down" from "not supported"
/// without catching exceptions. The `cause` field carries the original error
/// for diagnostics only; it must never be shown to an end user as-is, and none
/// of these types carry tokens, cookies or signed URLs in their message.
sealed class LiveSiteError {
  /// Creates an error for [siteId] with a human-readable [message] and an
  /// optional underlying [cause].
  const new({required this.siteId, required this.message, this.cause});

  /// The identifier of the site where the failure occurred.
  final String siteId;

  /// A human-readable diagnostic message.
  final String message;

  /// The original error, when available.
  final Object? cause;
}

/// The requested room, anchor, category or source does not exist.
final class LiveSiteNotFound extends LiveSiteError {
  /// A not-found failure for [siteId].
  const new({required super.siteId, required super.message});
}

/// The site does not support the requested operation.
final class LiveSiteUnsupported extends LiveSiteError {
  /// An unsupported-operation failure for [siteId].
  const new({required super.siteId, required super.message});
}

/// The operation failed because of a network problem.
final class LiveSiteNetworkError extends LiveSiteError {
  /// A network failure for [siteId], with an optional [cause].
  const new({required super.siteId, required super.message, super.cause});
}

/// The response could not be parsed or validated.
final class LiveSiteParseError extends LiveSiteError {
  /// A parse failure for [siteId], with an optional [cause].
  const new({required super.siteId, required super.message, super.cause});
}

/// The site requires authentication or authorization the session lacks.
final class LiveSiteAuthenticationError extends LiveSiteError {
  /// An authentication failure for [siteId].
  const new({required super.siteId, required super.message});
}

/// The platform rejected the request because of rate limiting.
final class LiveSiteRateLimitError extends LiveSiteError {
  /// A rate-limit failure for [siteId].
  const new({required super.siteId, required super.message});
}

/// An unexpected failure normalized at an API boundary.
final class LiveSiteUnexpectedError extends LiveSiteError {
  /// An unexpected failure for [siteId], with the [cause] that triggered it.
  const new({required super.siteId, required super.message, super.cause});
}
