import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Weibo platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum WeiboFailureKind {
  /// No such broadcast: an HTTP 404, an id that is no broadcast id, the
  /// detail's `error_code` 27401 ("LiveRoom does not exists!").
  notFound,

  /// The answer's shape changed under us: a body over the size limit or not
  /// JSON, a missing business `code`/`error_code` or one but 100000/0, an
  /// answer about another broadcast or anchor, a status, watch limit or play
  /// switch that is no integer, a snapshot list that is not a list, has over
  /// 500 rows or has rows but none usable.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the broadcast ended or never started, is restricted,
  /// switched off, or a live broadcast carries no media URL and a replay no
  /// recording.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not the recommendation
  /// snapshot, or a page or page size outside what the platform serves.
  invalidArgument,
}

/// A Weibo platform failure.
final class WeiboFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const WeiboFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final WeiboFailureKind kind;

  /// Diagnostic text (no token, cookie or signed URL).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary. A refusal
  /// folds into the throttle error: to a caller both read as "back off".
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    WeiboFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    WeiboFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    WeiboFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    WeiboFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    WeiboFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    WeiboFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    WeiboFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a broadcast that is gone, over, or kept from this client — an
  /// edge refusal does not lift on retry either.
  bool get isTransient => kind == WeiboFailureKind.network || kind == WeiboFailureKind.rateLimited;

  @override
  String toString() => 'WeiboFailure(${kind.name}: $message)';
}
