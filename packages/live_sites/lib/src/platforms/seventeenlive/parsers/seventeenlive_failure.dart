import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside 17LIVE, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free. The reference's `SiteError` classes map onto these one by one;
/// `RiskControl` (an HTTP 401/403 refusal of this client) has no variant of its
/// own here and is reported as a rate limit, the same way chzzk's gate is.
enum SeventeenLiveFailureKind {
  /// No such room: an id that is not a room id (1 to 12 digits, no leading
  /// zero), an HTTP 404, or the platform's `stream not found` answer (which it
  /// sends as HTTP 520, REG-17LIVE-004).
  notFound,

  /// The answer's shape changed under us (a body that is not JSON, a top level
  /// of the wrong kind, an answer for another room, a directory cursor that is
  /// not text or too long, an HTTP 400 or 420 — the latter being a refused
  /// parameter, which the platform shows as `errorCode` 7).
  apiChanged,

  /// The transport failed, or the site answered with a status no gate explains
  /// (a redirect included: 17LIVE requests never follow one).
  network,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// An HTTP 401 or 403: the platform refused this client.
  riskControl,

  /// Nothing to play: the room is offline, its state is one the platform did
  /// not name, a live is locked for this viewer (premium, army-only, other),
  /// the live carries no readable pull URL, or a quality the room does not
  /// offer was asked for.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not one of the regions, a
  /// directory cursor this adapter would not send, a page outside its range, a
  /// search page size below 1.
  invalidArgument,

  /// The chat cannot be joined: `messenger/auth` handed this room to another
  /// push service than Ably, so there is no protocol here to speak.
  chatRefused,
}

/// A 17LIVE platform failure.
final class SeventeenLiveFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const SeventeenLiveFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final SeventeenLiveFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    SeventeenLiveFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    SeventeenLiveFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    SeventeenLiveFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    SeventeenLiveFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    SeventeenLiveFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    SeventeenLiveFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    SeventeenLiveFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
    SeventeenLiveFailureKind.chatRefused => LiveSiteError.unsupported(siteId: siteId, message: message),
  };

  @override
  String toString() => 'SeventeenLiveFailure(${kind.name}: $message)';
}
