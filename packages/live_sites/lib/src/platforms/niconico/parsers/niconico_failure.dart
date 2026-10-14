import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the niconico platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum NiconicoFailureKind {
  /// The address names no room (a dead program, a gone watch page, a 404).
  notFound,

  /// The answer's shape changed under us.
  apiChanged,

  /// The transport failed (timeout, connection, 5xx).
  network,

  /// The operation needs a login that is not there (a `needLogin` program).
  needsLogin,

  /// The edge throttled us (HTTP 429, too many seat connections).
  rateLimited,

  /// The edge refused the client outright (401/403/406 access).
  riskControl,

  /// The program is scheduled, ended, or its access is denied so that an
  /// anonymous viewer cannot watch (a private, paid or followers-only
  /// program) — a room state, not a transport or shape failure.
  streamUnavailable,

  /// The program is set for a country this viewer is outside.
  regionBlocked,
}

/// A niconico platform failure.
final class NiconicoFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const NiconicoFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final NiconicoFailureKind kind;

  /// Diagnostic text (no secrets).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    NiconicoFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    NiconicoFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    NiconicoFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    NiconicoFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    NiconicoFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    NiconicoFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    NiconicoFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    NiconicoFailureKind.regionBlocked => LiveSiteError.authentication(siteId: siteId, message: message),
  };

  @override
  String toString() => 'NiconicoFailure(${kind.name}: $message)';
}
