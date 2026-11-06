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
  /// No such room: an HTTP 404, or the envelope's `code` 404 ("无资源", also
  /// the chat-address answer for a room that is not live).
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or over the
  /// read limit, a business code the gates do not name, a page that cannot be
  /// read at all, a room answer about another room, a stream address that is
  /// not LOOK's.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// LOOK refused the request: an HTTP 401 or 403, or the envelope's codes
  /// 424, 520, 522 and 555 on a list or chat answer (3.x's "access").
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play, with the reason: the room is offline, banned, in the
  /// app only, ticketed, private, or live without a usable stream.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not LOOK's, a quality
  /// the room does not name, a page past what the site ever served.
  invalidArgument,
}

/// A LOOK Live platform failure.
final class LookliveFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const LookliveFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final LookliveFailureKind kind;

  /// Diagnostic text.
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
  /// throttle can; a room that is gone, banned or app-only does not lift on
  /// retry, and neither does a body that broke the spec.
  bool get isTransient => kind == LookliveFailureKind.network || kind == LookliveFailureKind.rateLimited;

  @override
  String toString() => 'LookliveFailure(${kind.name}: $message)';
}
