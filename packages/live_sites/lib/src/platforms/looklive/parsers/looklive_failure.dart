import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the LOOK Live platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum LookliveFailureKind {
  /// No such room: an HTTP 404, an answer whose `code` is 404 ("无资源"), or
  /// a room id that is not a room number.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or too
  /// large, a business code no gate explains, a list whose entries cannot be
  /// read (when none can), a room answer about another room, a field of the
  /// wrong type.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session: HTTP 401 or 403, or the envelope's codes
  /// 424, 520, 522 and 555 where they mean "this client cannot watch".
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the room is not live, is banned, watchable in the LOOK
  /// app only, behind a ticket or a password, or live without a usable
  /// stream address.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not a LOOK Live area, a
  /// quality it has no name for, a page outside what it ever served.
  invalidArgument,
}

/// A LOOK Live platform failure.
final class LookliveFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const LookliveFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final LookliveFailureKind kind;

  /// Diagnostic text (no token, cookie or signed URL).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    LookliveFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    LookliveFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    LookliveFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    LookliveFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    LookliveFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    LookliveFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    LookliveFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone, banned, or kept from this client — an
  /// edge refusal does not lift on retry.
  bool get isTransient => kind == LookliveFailureKind.network || kind == LookliveFailureKind.rateLimited;

  @override
  String toString() => 'LookliveFailure(${kind.name}: $message)';
}
