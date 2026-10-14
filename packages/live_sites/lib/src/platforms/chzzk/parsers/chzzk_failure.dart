import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the chzzk platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum ChzzkFailureKind {
  /// No such channel: an id that is not a channel id (32 lower-case hex
  /// digits), an HTTP 404, or the platform's answer for an unknown channel
  /// (HTTP 200 with a null `channelId` and the name `(알 수 없음)`).
  notFound,

  /// The answer's shape changed under us (a non-200 `code`, a body that is not
  /// JSON, an answer for another channel, an unknown `status`, a master
  /// playlist that is not one, an answer over the size limit).
  apiChanged,

  /// The transport failed, the site answered with a status no gate explains
  /// (a redirect included: chzzk requests never follow one), or a page replay
  /// passed its deadline.
  network,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Chzzk's gate: an HTTP 401 or 403.
  riskControl,

  /// Watching needs the platform's own account and age check (an adult live
  /// has no anonymous media source).
  needsLogin,

  /// The live is hidden from here (`krOnlyViewing`, or `blindType` `ABROAD`).
  regionBlocked,

  /// Nothing to play: the channel is offline, the master is gone (its 404),
  /// the live is paid, or a live answer carries no usable playback data.
  streamUnavailable,

  /// A request the caller got wrong: an area that is not the platform's, a
  /// cursor this adapter never made, a page outside its range, a quality the
  /// live does not offer.
  invalidArgument,
}

/// A chzzk platform failure.
final class ChzzkFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const ChzzkFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final ChzzkFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    ChzzkFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    ChzzkFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    ChzzkFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    ChzzkFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    ChzzkFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    ChzzkFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    ChzzkFailureKind.regionBlocked => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    ChzzkFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    ChzzkFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  @override
  String toString() => 'ChzzkFailure(${kind.name}: $message)';
}
