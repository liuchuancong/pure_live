import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the huya platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum HuyaFailureKind {
  /// The address names no room (a dead rid, a letter alias `profileRoom`
  /// refuses, HTTP 422).
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

  /// The room is on air but pushes no stream, its credential expired, or
  /// the room is restricted so nothing is opened.
  streamUnavailable,
}

/// A huya platform failure.
final class HuyaFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const HuyaFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final HuyaFailureKind kind;

  /// Diagnostic text (no secrets).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    HuyaFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    HuyaFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    HuyaFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    HuyaFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    HuyaFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    HuyaFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    HuyaFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'HuyaFailure(${kind.name}: $message)';
}
