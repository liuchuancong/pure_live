import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Inke platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum InkeFailureKind {
  /// No such room or channel: an HTTP 404, an id that is not a uid, a channel
  /// the catalog does not list.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or too
  /// large, a missing business code or one but zero, an answer about another
  /// anchor, a list that is not a list.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the anchor is not live, or no showcase holds the
  /// broadcast's pull URL.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not an Inke showcase, a
  /// quality it has no name for, a page or keyword outside what it serves.
  invalidArgument,
}

/// An Inke platform failure.
final class InkeFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const InkeFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final InkeFailureKind kind;

  /// Diagnostic text (no token, cookie or signed URL).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary. A refusal
  /// folds into the throttle error: to a caller both read as "back off".
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    InkeFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    InkeFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    InkeFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    InkeFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    InkeFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    InkeFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    InkeFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone, over, or kept from this client — an edge
  /// refusal does not lift on retry either.
  bool get isTransient => kind == InkeFailureKind.network || kind == InkeFailureKind.rateLimited;

  @override
  String toString() => 'InkeFailure(${kind.name}: $message)';
}
