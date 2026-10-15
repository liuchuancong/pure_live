import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Steam Broadcast platform, as the parsers throw
/// it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum SteambroadcastFailureKind {
  /// No such answer or account: an HTTP 404, a watch page without a
  /// broadcast config, or a room id that is not a Steam id.
  notFound,

  /// The answer's shape changed under us: HTTP 400 or 422, a body that is
  /// not JSON (or not an object) or too large, a field of the wrong type,
  /// an `hls_url` or CDN parameters that break the address rules, a master
  /// that fails its check, or an answer about another account.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect, 204).
  network,

  /// The edge refused the session (HTTP 401 or 403, Akamai's refusal page).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the broadcaster is offline, waiting or in an unknown
  /// state, the account may not broadcast, the broadcast is for subscribers
  /// only, or its media failed to load or to check.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not the trending
  /// broadcasts, a quality the room does not offer, a page past what the
  /// platform serves.
  invalidArgument,
}

/// A Steam Broadcast platform failure.
final class SteambroadcastFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const SteambroadcastFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final SteambroadcastFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary. A 401 or
  /// 403 refusal folds into the rate-limit error, like the other platforms'
  /// risk-control kind.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    SteambroadcastFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    SteambroadcastFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    SteambroadcastFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    SteambroadcastFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    SteambroadcastFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    SteambroadcastFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    SteambroadcastFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a broadcaster that is gone, offline, or kept from this
  /// client — an edge refusal does not lift on retry.
  bool get isTransient => kind == SteambroadcastFailureKind.network || kind == SteambroadcastFailureKind.rateLimited;

  @override
  String toString() => 'SteambroadcastFailure(${kind.name}: $message)';
}
