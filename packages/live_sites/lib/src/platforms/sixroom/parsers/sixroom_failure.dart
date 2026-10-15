import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Six Rooms platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum SixroomFailureKind {
  /// No such room or broadcaster: an HTTP 404 or 410, a room page that is a
  /// prompt page, or an inroom answer with the site's "cannot enter" flag.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON, is not an
  /// object or is too large, a flag that is no flag at all, a page or answer
  /// whose identity does not match, a list without its rows, or a stream
  /// name that does not name this broadcaster and broadcast.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx and every other status).
  network,

  /// The site refused the session (HTTP 401 or 403, a redirect, a risk
  /// control flag of an answer).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the room is offline or its state is unknown, is a
  /// private room or shows a black screen, was read without its stream, or
  /// names an unusable stream.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not one of the six, a
  /// quality it has no name for, a page outside what it ever served.
  invalidArgument,
}

/// A Six Rooms platform failure.
final class SixroomFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const SixroomFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final SixroomFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary. The
  /// site's refusals (401, 403, risk control) fold into a rate limit like an
  /// edge throttle does.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    SixroomFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    SixroomFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    SixroomFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    SixroomFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    SixroomFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    SixroomFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    SixroomFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone, over, or kept from this client.
  bool get isTransient => kind == SixroomFailureKind.network || kind == SixroomFailureKind.rateLimited;

  @override
  String toString() => 'SixroomFailure(${kind.name}: $message)';
}
