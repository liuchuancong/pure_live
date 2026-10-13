import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the douyu platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum DouyuFailureKind {
  /// The address names no room (a dead rid, a closed 靓号, HTML error page).
  notFound,

  /// The answer's shape changed under us.
  apiChanged,

  /// The transport failed (timeout, connection, 5xx).
  network,

  /// The operation needs a login that is not there.
  needsLogin,

  /// The edge throttled us.
  rateLimited,

  /// The edge refused the client outright (a bare 403).
  riskControl,

  /// The room is on air but pushes no stream, or the play API refused with
  /// a room-state code a retry cannot fix.
  streamUnavailable,
}

/// A douyu platform failure.
final class DouyuFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const DouyuFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final DouyuFailureKind kind;

  /// Diagnostic text (no secrets).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    DouyuFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    DouyuFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    DouyuFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    DouyuFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    DouyuFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    DouyuFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    DouyuFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'DouyuFailure(${kind.name}: $message)';
}
