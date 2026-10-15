import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the LiveMe platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum LivemeFailureKind {
  /// No such room, anchor or broadcast: an HTTP 404, a business status 400
  /// or 404, or a 500 that says "user not exist".
  notFound,

  /// The answer's shape changed under us: an HTTP 400, a body that is not
  /// JSON or too large, a business status no gate explains, an answer about
  /// another room or anchor, or a row of a list that cannot be read (when
  /// none can).
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403, or the business 401).
  riskControl,

  /// The edge throttled us (HTTP 420 or 429, or the business 420).
  rateLimited,

  /// Nothing to play: the anchor is not broadcasting, the broadcast is over,
  /// is private or paid, or carries no media URL.
  streamUnavailable,

  /// A request the caller got wrong: a page below 1, or a keyword over the
  /// platform's limit.
  invalidArgument,
}

/// A LiveMe platform failure.
final class LivemeFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const LivemeFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final LivemeFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary. A
  /// refusal folds into the rate-limit error: an edge that refuses this
  /// anonymous client will not answer again either.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    LivemeFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    LivemeFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    LivemeFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    LivemeFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    LivemeFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    LivemeFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    LivemeFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone, not broadcasting, or kept from this
  /// client — an edge refusal does not lift on retry.
  bool get isTransient => kind == LivemeFailureKind.network || kind == LivemeFailureKind.rateLimited;

  @override
  String toString() => 'LivemeFailure(${kind.name}: $message)';
}
