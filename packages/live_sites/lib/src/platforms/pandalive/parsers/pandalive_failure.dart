import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the PandaTV platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum PandaliveFailureKind {
  /// No such broadcaster: an HTTP 404, or a refusal whose message names an
  /// unknown user.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or too
  /// large, an answer without the `result` flag, a refusal without a code,
  /// a page whose echo or identity does not match, an answer about another
  /// broadcaster.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the broadcast is not live, ended, adult, password
  /// protected, fans only, needs a login the anonymous adapter has, or has
  /// no HLS master or no video variant.
  streamUnavailable,

  /// A request the caller got wrong: a page outside what the platform ever
  /// served, an area that is not one of the two directories, a keyword with
  /// a control character.
  invalidArgument,
}

/// A PandaTV platform failure.
final class PandaliveFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const PandaliveFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final PandaliveFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    PandaliveFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    PandaliveFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    PandaliveFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    PandaliveFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    PandaliveFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    PandaliveFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    PandaliveFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a broadcast that is over or kept from this client — an edge
  /// refusal does not lift on retry.
  bool get isTransient => kind == PandaliveFailureKind.network || kind == PandaliveFailureKind.rateLimited;

  @override
  String toString() => 'PandaliveFailure(${kind.name}: $message)';
}
