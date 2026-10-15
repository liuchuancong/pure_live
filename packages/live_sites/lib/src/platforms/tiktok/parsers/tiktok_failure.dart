import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the TikTok platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum TiktokFailureKind {
  /// No such user or LIVE room: a `user_not_found` answer, a `room/info`
  /// status code other than 0, an HTTP 404, or a room id that is no TikTok
  /// username at all.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON, too large
  /// or of the wrong kind, a business code no gate explains, a stream
  /// container nothing readable could be taken from, an answer about another
  /// user or LIVE room.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect on an API request).
  network,

  /// The site refused the anonymous client (HTTP 401 or 403, an empty 200).
  riskControl,

  /// The edge throttled us (HTTP 420 or 429).
  rateLimited,

  /// Nothing to play: the user is offline, the site's state is not known,
  /// the LIVE is for a restricted audience, or it carries no stream.
  streamUnavailable,

  /// A request the caller got wrong: a directory page below 1.
  invalidArgument,
}

/// A TikTok platform failure.
final class TiktokFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const TiktokFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final TiktokFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    TiktokFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    TiktokFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    TiktokFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    TiktokFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    TiktokFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    TiktokFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    TiktokFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a user that is gone or a LIVE it may not watch — an edge
  /// refusal does not lift on retry.
  bool get isTransient => kind == TiktokFailureKind.network || kind == TiktokFailureKind.rateLimited;

  @override
  String toString() => 'TiktokFailure(${kind.name}: $message)';
}
