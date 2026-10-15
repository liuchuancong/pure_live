import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Missevan platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum MissevanFailureKind {
  /// No such room: an HTTP 404, or the envelope's only unknown-room code
  /// (500030004).
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or too
  /// large, an envelope whose `code` is neither 0 nor the unknown-room code,
  /// a row of a list that cannot be read (when none can), a page whose echo
  /// does not match, an answer about another room, a live room without a
  /// usable pull URL.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the request (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the room is offline, or live without a usable pull
  /// URL.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not a Missevan tab, a
  /// quality the room does not offer, a page or page size outside what the
  /// site ever served, a keyword with control characters.
  invalidArgument,
}

/// A Missevan platform failure.
final class MissevanFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const MissevanFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final MissevanFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    MissevanFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    MissevanFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    MissevanFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    MissevanFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    MissevanFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    MissevanFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    MissevanFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone or offline — an edge refusal does not
  /// lift on retry.
  bool get isTransient => kind == MissevanFailureKind.network || kind == MissevanFailureKind.rateLimited;

  @override
  String toString() => 'MissevanFailure(${kind.name}: $message)';
}
