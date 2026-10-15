import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the KilaKila platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum KilakilaFailureKind {
  /// No such anchor or broadcast: an HTTP 404, a profile whose `code` is
  /// 1013, a `getRoomInfo` whose `h.code` is 5201.
  notFound,

  /// The answer's shape changed under us: HTTP 400-class shapes no gate
  /// explains, a body that is not JSON or too large, a business code but
  /// 200/1013/5201/5966, a row of a list that cannot be read (when none
  /// can), an answer about another anchor or broadcast.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the anchor has no current broadcast, the broadcast
  /// ended or is a historical replay, is paid, or answers no pull URL.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not a KilaKila
  /// timeline, a quality it has no name for, a page or page size outside
  /// what it ever served.
  invalidArgument,
}

/// A KilaKila platform failure.
final class KilakilaFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const KilakilaFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final KilakilaFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    KilakilaFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    KilakilaFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    KilakilaFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    KilakilaFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    KilakilaFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    KilakilaFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    KilakilaFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on an anchor or broadcast that is gone, over, or kept from this
  /// client — an edge refusal does not lift on retry.
  bool get isTransient => kind == KilakilaFailureKind.network || kind == KilakilaFailureKind.rateLimited;

  @override
  String toString() => 'KilakilaFailure(${kind.name}: $message)';
}
