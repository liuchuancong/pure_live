import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the YY platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum YyFailureKind {
  /// No such channel: the room page is the 404 page, or the id is not a
  /// channel number.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON, a
  /// `resultCode` but 0, a room page without its `pageInfo`, a stream
  /// answer of another shape.
  apiChanged,

  /// The transport failed, or the site answered 5xx.
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the channel broadcasts nothing either route can take,
  /// or a quality names no stream.
  streamUnavailable,

  /// A request the caller got wrong: a quality with no id, an area outside
  /// the catalog, a page below 1.
  invalidArgument,
}

/// A YY platform failure.
final class YyFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const YyFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final YyFailureKind kind;

  /// Diagnostic text (no cookie, no signed URL).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    YyFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    YyFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    YyFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    YyFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    YyFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    YyFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    YyFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend
  /// a request on a channel that is gone or kept from this client.
  bool get isTransient => kind == YyFailureKind.network || kind == YyFailureKind.rateLimited;

  @override
  String toString() => 'YyFailure(${kind.name}: $message)';
}
