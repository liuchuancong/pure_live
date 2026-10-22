import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Baidu Live platform, as the parsers and the
/// transport wrapper throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum BaiduliveFailureKind {
  /// No such room: HTTP 404 or 410, a room command without its `371`
  /// (`error_code` 1 or 4, or neither `host` nor `video`), a room id that is
  /// neither a room number nor a room link.
  notFound,

  /// The answer's shape changed under us: a body over the size limit or not
  /// JSON, an `errno` or a feed `inner_errno` that is not 0, a session or a
  /// refresh index the feed did not name, a room command whose `error_code`
  /// is another number or whose `share_url` names another room.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// Baidu refused this client: HTTP 401 or 403. [LiveSiteError] has no
  /// risk-control variant, so this is reported as a throttle, as every other
  /// platform here reports an edge refusal.
  riskControl,

  /// The room is not served in this region: HTTP 451.
  regionBlocked,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: a broadcast that is neither live nor ended, a paid,
  /// forbidden or banned one, an ended one without a recording, a live one
  /// without a stream this client accepts, or a quality the room no longer
  /// offers.
  streamUnavailable,

  /// A request the caller got wrong: a page past the last one the directory
  /// ever served, an area that is not a Baidu Live channel.
  invalidArgument,
}

/// A Baidu Live platform failure.
final class BaiduliveFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const BaiduliveFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final BaiduliveFailureKind kind;

  /// Diagnostic text (no token, cookie or signed URL).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    BaiduliveFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    BaiduliveFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    BaiduliveFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    BaiduliveFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    BaiduliveFailureKind.regionBlocked => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    BaiduliveFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    BaiduliveFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    BaiduliveFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone, restricted, or refused by the edge — an
  /// edge refusal does not lift on retry.
  bool get isTransient => kind == BaiduliveFailureKind.network || kind == BaiduliveFailureKind.rateLimited;

  @override
  String toString() => 'BaiduliveFailure(${kind.name}: $message)';
}
