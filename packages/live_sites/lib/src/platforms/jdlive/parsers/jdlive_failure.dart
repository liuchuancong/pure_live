import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the JD Live platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum JdliveFailureKind {
  /// No such broadcast: an HTTP 404, or an envelope whose `subCode` is not
  /// `0` (the site's shape for a broadcast that is gone).
  notFound,

  /// The answer's shape changed under us: HTTP 400 or 422, a body that is
  /// not JSON or too large, an envelope whose `code` is not `0`, an answer
  /// about another broadcast, a field of the wrong type, or a playlist that
  /// fails its check.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx and every other status; a redirect would land on a page
  /// whose HTML is not an answer).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the broadcast is announced or already over, is for
  /// JD's app only, is live without an address, or is a replay without its
  /// recording.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not the platform's, a
  /// quality it has no name for, a page outside what it ever served.
  invalidArgument,
}

/// A JD Live platform failure.
final class JdliveFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const JdliveFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final JdliveFailureKind kind;

  /// Diagnostic text (no token, cookie or signed URL).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    JdliveFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    JdliveFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    JdliveFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    JdliveFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    JdliveFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    JdliveFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    JdliveFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a broadcast that is gone, over, or kept from anonymous
  /// viewers — and an edge that refuses this client does not lift on retry.
  bool get isTransient => kind == JdliveFailureKind.network || kind == JdliveFailureKind.rateLimited;

  @override
  String toString() => 'JdliveFailure(${kind.name}: $message)';
}
