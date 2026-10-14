import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the bigo platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum BigoFailureKind {
  /// The id names no studio (`code` 0 with neither `uid` nor `clientBigoId`,
  /// an HTTP 404, an id that is not a Bigo id).
  notFound,

  /// The answer's shape changed under us (a non-zero `code`, a field of the
  /// wrong type, a JSONP answer that is not JSONP of the callback we sent, a
  /// body over the size limit).
  apiChanged,

  /// The transport failed, the site answered with a status no gate explains
  /// (a redirect included: bigo requests never follow one), or the token and
  /// studio requests together passed their deadline.
  network,

  /// Bigo's gate: an HTTP 401 or 403.
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// The studio cannot be watched here: offline, a password or paid room, or a
  /// live room whose answer carries no `hls_src`.
  streamUnavailable,

  /// The studio answers `needLogin`: watching needs the platform's own login.
  needsLogin,
}

/// A bigo platform failure.
final class BigoFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const BigoFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final BigoFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    BigoFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    BigoFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    BigoFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    BigoFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    BigoFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    BigoFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    BigoFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
  };

  @override
  String toString() => 'BigoFailure(${kind.name}: $message)';
}
