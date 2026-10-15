import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the CC platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum CcFailureKind {
  /// No such room or anchor: a non-numeric room id, an HTTP 400 of
  /// `activitylives`, a room page whose `roomInfoInitData` answers code 404
  /// ("no ccid").
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or too
  /// large, an envelope whose `code` is not the endpoint's, an answer about
  /// another anchor, a field of the wrong type, a page over the platform's
  /// own row limit.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the anchor is not broadcasting, or the play answer
  /// says the channel has no stream (HTTP 410 "Gone", 404).
  streamUnavailable,

  /// A request the caller got wrong: an area that is not a CC game type, a
  /// page or page size outside what the platform ever serves.
  invalidArgument,
}

/// A CC platform failure.
final class CcFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const CcFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final CcFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    CcFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    CcFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    CcFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    CcFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    CcFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    CcFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    CcFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on an anchor that is gone or on a channel that is over — and an
  /// edge that refuses this client does not lift on retry.
  bool get isTransient => kind == CcFailureKind.network || kind == CcFailureKind.rateLimited;

  @override
  String toString() => 'CcFailure(${kind.name}: $message)';
}
