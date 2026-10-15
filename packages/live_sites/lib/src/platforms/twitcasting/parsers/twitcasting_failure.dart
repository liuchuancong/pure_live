import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the TwitCasting platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum TwitcastingFailureKind {
  /// No such channel: an HTTP 404, a channel page the site sends home (a
  /// redirect), or `streamserver.php` answering `{}`.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or not the
  /// list it should be, a channel page that does not name the channel, a
  /// broadcast without a readable movie id or without a valid stream tier,
  /// a row of a list that cannot be read (when none can).
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect of an API).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the channel is not broadcasting, or its broadcast is
  /// password-protected (the secret word), private or otherwise not played
  /// for this anonymous viewer.
  streamUnavailable,

  /// A request the caller got wrong: a room id that is not a channel, an
  /// area that is not a homepage tab, a page or page size outside what the
  /// platform ever serves, a keyword over its limit.
  invalidArgument,
}

/// A TwitCasting platform failure.
final class TwitcastingFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const TwitcastingFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final TwitcastingFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    TwitcastingFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    TwitcastingFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    TwitcastingFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    TwitcastingFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    TwitcastingFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    TwitcastingFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    TwitcastingFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a channel that is gone or kept from this client — an edge
  /// refusal does not lift on retry.
  bool get isTransient => kind == TwitcastingFailureKind.network || kind == TwitcastingFailureKind.rateLimited;

  @override
  String toString() => 'TwitcastingFailure(${kind.name}: $message)';
}
