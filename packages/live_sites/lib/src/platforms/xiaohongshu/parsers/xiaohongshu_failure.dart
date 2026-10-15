import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Xiaohongshu platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum XiaohongshuFailureKind {
  /// No such room: an HTTP 404, or the share page's `pageStatus` "error"
  /// ("未找到直播间，请稍后再试").
  notFound,

  /// The answer's shape changed under us: a body that is not one hydration
  /// state, a field of the wrong shape, a live page naming another room, or
  /// a `pullConfig` without one usable address.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401, 403 or 406, its risk control).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the room ended, its state is not known, it is paid or
  /// limited to a group the viewer is not in, or it names no pull address.
  streamUnavailable,

  /// The page does not tell whether the room is public, so playing needs a
  /// signed-in account (3.x's `NeedsLogin`).
  needsLogin,

  /// The room is fenced to a region the viewer is not in (`joinLimitTypes`
  /// IP fence).
  regionBlocked,

  /// A request the caller got wrong: a page below 1.
  invalidArgument,
}

/// A Xiaohongshu platform failure.
final class XiaohongshuFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const XiaohongshuFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final XiaohongshuFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    XiaohongshuFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    XiaohongshuFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    XiaohongshuFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    XiaohongshuFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    XiaohongshuFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    XiaohongshuFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    XiaohongshuFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    XiaohongshuFailureKind.regionBlocked => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    XiaohongshuFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone, over, or kept from this client — an
  /// edge refusal does not lift on retry.
  bool get isTransient => kind == XiaohongshuFailureKind.network || kind == XiaohongshuFailureKind.rateLimited;

  @override
  String toString() => 'XiaohongshuFailure(${kind.name}: $message)';
}
