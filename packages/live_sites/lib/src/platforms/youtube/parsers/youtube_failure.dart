import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the youtube platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum YoutubeFailureKind {
  /// The address names no room (`ERROR` playability, a malformed id, a
  /// resolve_url that reaches no watch or browse endpoint).
  notFound,

  /// The answer's shape changed under us (a missing `videoDetails`, a body
  /// that is not JSON, a 400 with no usable payload, a media host off the
  /// allowlist or a URL carrying user info or a fragment).
  apiChanged,

  /// The transport failed (timeout, connection, HTTP 5xx).
  network,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Google's risk control or consent gate (HTTP 401/403, `LOGIN_REQUIRED`).
  riskControl,

  /// The video plays no stream for this client (`UNPLAYABLE`,
  /// `LIVE_CONTENT_NOT_AVAILABLE`, a live that names no manifest URL).
  streamUnavailable,
}

/// A youtube platform failure.
final class YouTubeFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const YouTubeFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final YoutubeFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    YoutubeFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    YoutubeFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    YoutubeFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    YoutubeFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    YoutubeFailureKind.riskControl => LiveSiteError.authentication(siteId: siteId, message: message),
    YoutubeFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'YouTubeFailure(${kind.name}: $message)';
}
