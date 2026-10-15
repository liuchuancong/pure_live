import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the SHOWROOM platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum ShowroomFailureKind {
  /// No such room, room key or genre: an HTTP 404, or a genre the snapshot no
  /// longer has.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON, an answer
  /// about another room, a row of a list that cannot be read (when none can),
  /// a live state or stream tier the platform does not name.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the room is offline, or offers no readable HLS tier.
  streamUnavailable,

  /// A request the caller got wrong: a page below 1, an area that is not a
  /// SHOWROOM genre.
  invalidArgument,
}

/// A SHOWROOM platform failure.
final class ShowroomFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const ShowroomFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final ShowroomFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary. The
  /// edge's refusals (HTTP 401 and 403) fold into the rate-limit error: a
  /// session the site keeps out does not lift on retry either.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    ShowroomFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    ShowroomFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    ShowroomFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    ShowroomFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    ShowroomFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    ShowroomFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    ShowroomFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone, offline, or kept from this client — an
  /// edge refusal does not lift on retry.
  bool get isTransient => kind == ShowroomFailureKind.network || kind == ShowroomFailureKind.rateLimited;

  @override
  String toString() => 'ShowroomFailure(${kind.name}: $message)';
}
