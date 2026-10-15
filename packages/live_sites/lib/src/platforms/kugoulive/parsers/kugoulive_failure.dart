import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Kugou Live platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum KugouliveFailureKind {
  /// No such room: an HTTP 404 or 410, or a room info that names no anchor.
  notFound,

  /// The answer's shape changed under us: a 400-class status, a body that is
  /// not JSON or too large, a business code but 0, an empty `data`, an
  /// answer about another room.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The site blocked this region (HTTP 451); folded to content-unavailable
  /// at the boundary (v2 has no region kind).
  regionBlocked,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// The room is offline, has no live session, or answers no playable
  /// stream.
  streamUnavailable,

  /// Watching needs a Kugou account (the stream answer's code -1).
  needsLogin,

  /// A request the caller got wrong: an area that is not the platform's, a
  /// quality it has no name for, a page outside what it ever served.
  invalidArgument,
}

/// A Kugou Live platform failure.
final class KugouliveFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const KugouliveFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final KugouliveFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    KugouliveFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    KugouliveFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    KugouliveFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    KugouliveFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    KugouliveFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    KugouliveFailureKind.regionBlocked => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    KugouliveFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    KugouliveFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    KugouliveFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can — an edge refusal or a region block does not lift on
  /// retry.
  bool get isTransient => kind == KugouliveFailureKind.network || kind == KugouliveFailureKind.rateLimited;

  @override
  String toString() => 'KugouliveFailure(${kind.name}: $message)';
}
