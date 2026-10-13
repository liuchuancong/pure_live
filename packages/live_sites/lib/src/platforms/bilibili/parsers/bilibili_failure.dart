import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the bilibili platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum BilibiliFailureKind {
  /// The address names no room (`-404`, `19002000`, `60004`, a room id that
  /// is not a number).
  notFound,

  /// The answer's shape changed under us (an unexpected code, a missing
  /// `room_info`, a body that is not JSON).
  apiChanged,

  /// The transport failed (timeout, connection, HTTP 5xx).
  network,

  /// The operation needs a login that is not there (code `-101`).
  needsLogin,

  /// The edge throttled us (HTTP 412, code `-412`).
  rateLimited,

  /// Bilibili's WBI risk control (`-352`): the signed request was refused
  /// outright. Reported as a rate limit, and answered by renewing the WBI
  /// keys, the guest buvid and the access id.
  riskControl,

  /// The room has no stream for this client (offline, a paid broadcast
  /// without a ticket, a carousel with nothing in rotation).
  streamUnavailable,
}

/// A bilibili platform failure.
final class BilibiliFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const BilibiliFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final BilibiliFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    BilibiliFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    BilibiliFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    BilibiliFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    BilibiliFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    BilibiliFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    BilibiliFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    BilibiliFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'BilibiliFailure(${kind.name}: $message)';
}
