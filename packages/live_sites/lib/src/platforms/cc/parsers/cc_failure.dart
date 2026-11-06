import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the NetEase CC platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum CcFailureKind {
  /// No such room or account: a non-numeric id, an HTTP 400 of
  /// `activitylives`, a room page whose `code` is 404, or a follow refresh
  /// whose existence check says the id is no account (9-7).
  notFound,

  /// The answer's shape changed under us: a body that is not JSON, an
  /// envelope whose `code` is wrong, an answer about another room, a field
  /// of the wrong type, or a play answer without any URL.
  apiChanged,

  /// The transport failed, or the site answered 5xx.
  network,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the anchor is not broadcasting (`video_play_url`'s
  /// HTTP 410 "no live", or 404), or the id asked of it is not a ccid.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not one of the
  /// catalog's live areas, or a page or size outside what the site serves.
  invalidArgument,
}

/// A NetEase CC platform failure.
final class CcFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const CcFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final CcFailureKind kind;

  /// Diagnostic text (no token, cookie or signed URL).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    CcFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    CcFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    CcFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    CcFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    CcFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    CcFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a room that is gone or not broadcasting.
  bool get isTransient => kind == CcFailureKind.network || kind == CcFailureKind.rateLimited;

  @override
  String toString() => 'CcFailure(${kind.name}: $message)';
}
