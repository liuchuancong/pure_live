import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the SOOP platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum SoopFailureKind {
  /// No such streamer: an id that is not a SOOP streamer id, or a station
  /// answer that names no streamer (HTTP 515, `code` 9000).
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or too
  /// large, a `CHANNEL` or `RESULT` the player API no longer carries, a list
  /// that is not a list, a broadcast number or stream manager that is not
  /// there, a stream assignment without its playlist.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx and every other non-2xx).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Watching needs the platform's own account and age check: an
  /// age-restricted broadcast answers no stream without a login.
  needsLogin,

  /// Nothing to play: the broadcast is password-protected or for
  /// subscribers only, the streamer is off the air or blocked, or the
  /// assignment refused a key.
  streamUnavailable,

  /// A request the caller got wrong: a quality the broadcast does not offer,
  /// a page outside what it ever served.
  invalidArgument,
}

/// A SOOP platform failure.
final class SoopFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const SoopFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final SoopFailureKind kind;

  /// Diagnostic text (no cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    SoopFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    SoopFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    SoopFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    SoopFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    SoopFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    SoopFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    SoopFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    SoopFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a streamer that is gone or a broadcast that is kept from
  /// this client — an edge refusal does not lift on retry.
  bool get isTransient => kind == SoopFailureKind.network || kind == SoopFailureKind.rateLimited;

  @override
  String toString() => 'SoopFailure(${kind.name}: $message)';
}
