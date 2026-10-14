import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the kick platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum KickFailureKind {
  /// No such channel or subcategory (HTTP 404, a slug that cannot name a
  /// channel, a directory filter with no row of it).
  notFound,

  /// The answer's shape changed under us (no envelope, a body that is not
  /// JSON, an answer for another channel, a playlist that is not one).
  apiChanged,

  /// The transport failed (timeout, connection, 5xx).
  network,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// The edge refused the client outright (Cloudflare's 401/403 refusal of
  /// a non-browser TLS handshake).
  riskControl,

  /// Nothing to play: the channel is offline or banned, its `playback_url`
  /// names no IVS host, or the master playlist was refused or holds no
  /// variant.
  streamUnavailable,
}

/// A kick platform failure.
final class KickFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const KickFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final KickFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    KickFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    KickFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    KickFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    KickFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    KickFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    KickFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'KickFailure(${kind.name}: $message)';
}
