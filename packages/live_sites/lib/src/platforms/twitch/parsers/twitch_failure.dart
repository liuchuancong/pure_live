import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the twitch platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum TwitchFailureKind {
  /// No such channel or directory (a login that is not one, `user: null`, a
  /// `PlaybackAccessToken` for an unknown channel, an unknown game slug).
  notFound,

  /// The answer's shape changed under us (no envelope, no `data`, a persisted
  /// query that is no longer known, a body that is not JSON, a master
  /// playlist that is not a playlist, an answer for another login).
  apiChanged,

  /// The transport failed (timeout, connection, HTTP 5xx).
  network,

  /// Twitch throttled us (HTTP 429).
  rateLimited,

  /// Twitch's integrity gate: an `extensions.challenge` or an error naming a
  /// failed integrity check. Lists end quietly on it; a first page reports it.
  riskControl,

  /// The stored session was refused (HTTP 401, or a token whose `claims`
  /// forbid this viewer for a non-geographic reason).
  needsLogin,

  /// This viewer may not watch from here (a `geo` reason in the access
  /// token's claims, or usher's 403 naming geo).
  regionBlocked,

  /// Nothing to play: the channel is offline, usher answered 404, or the
  /// master playlist holds no variant.
  streamUnavailable,
}

/// A twitch platform failure.
final class TwitchFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const TwitchFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final TwitchFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    TwitchFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    TwitchFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    TwitchFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    TwitchFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    TwitchFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    TwitchFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    TwitchFailureKind.regionBlocked => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    TwitchFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'TwitchFailure(${kind.name}: $message)';
}
