import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the acfun platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum AcfunFailureKind {
  /// No such author (`live/info` with no user, an id that is not an author
  /// id, a search card whose link does not name one).
  notFound,

  /// The answer's shape changed under us (a body that is no JSON object, a
  /// `result` that should not be, a list without `liveList` or `pcursor`, a
  /// `startPlay` without a `liveId`, a search answer whose cards do not add
  /// up to its total).
  apiChanged,

  /// The transport failed (timeout, connection, HTTP 5xx).
  network,

  /// AcFun throttled us (HTTP 429).
  rateLimited,

  /// AcFun's gate: HTTP 401/403, a `visitor/login` or `gift/list` with a
  /// refusal `result`, or a `startPlay` result that is neither success nor a
  /// known room state (the session was refused).
  riskControl,

  /// The paid show the viewer has no ticket for (`startPlay` 380205), or a
  /// quality the answer does not carry.
  paid,

  /// Nothing to play: the broadcast ended (`startPlay` 129004) or the answer
  /// holds no playable representation.
  streamUnavailable,
}

/// An acfun platform failure.
final class AcfunFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const AcfunFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final AcfunFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    AcfunFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    AcfunFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    AcfunFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    AcfunFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    AcfunFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    AcfunFailureKind.paid => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    AcfunFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'AcfunFailure(${kind.name}: $message)';
}
