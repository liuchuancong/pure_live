import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the FC2 Live platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum Fc2LiveFailureKind {
  /// No such channel: an HTTP 404, a member answer whose `status` is not `1`,
  /// or one that answers with no owner (the site's shape for a channel that
  /// never existed).
  notFound,

  /// The answer's shape changed under us: HTTP 400 or 422, a body that is not
  /// JSON or too large, an answer about another channel, a field of the wrong
  /// type where the platform's own readers demand one, a grant that is not a
  /// control socket of the channel, or a control whose HLS answer names no
  /// playlist.
  apiChanged,

  /// The transport failed, the site answered with a status no gate explains
  /// (a redirect included: FC2 requests never follow one), a control's startup
  /// passed its deadline, or a socket broke mid-handshake.
  network,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// The site refused the session (HTTP 401 or 403): a shared address that has
  /// started blocking this client.
  riskControl,

  /// Watching needs an FC2 account: the broadcast is for signed-in viewers, or
  /// for those signed in and holding points. This client is anonymous.
  needsLogin,

  /// Nothing to play: the channel is not on air, its broadcast is restricted by
  /// FC2, it is paid or ticketed, its grant says no, or its HLS answer has no
  /// playlist of the asked quality.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not the platform's, a
  /// quality the platform has no name for, a page or page size outside what it
  /// ever served.
  invalidArgument,
}

/// An FC2 Live platform failure.
final class Fc2LiveFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const Fc2LiveFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final Fc2LiveFailureKind kind;

  /// Diagnostic text (no token, cookie or grant).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    Fc2LiveFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    Fc2LiveFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    Fc2LiveFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    Fc2LiveFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    Fc2LiveFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    Fc2LiveFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    Fc2LiveFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    Fc2LiveFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying (the comment
  /// connection, which takes a fresh grant per handshake) does not spend a
  /// request on a channel that is gone, offline or restricted.
  bool get isTransient =>
      kind == Fc2LiveFailureKind.network ||
      kind == Fc2LiveFailureKind.rateLimited ||
      kind == Fc2LiveFailureKind.riskControl;

  @override
  String toString() => 'Fc2LiveFailure(${kind.name}: $message)';
}
