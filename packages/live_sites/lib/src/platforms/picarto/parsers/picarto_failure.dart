import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the Picarto platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations map
/// them onto [LiveSiteError] values at the Either boundary (ARCHITECTURE.md §5)
/// — inside the platform they stay exceptions so the pure parsing code stays
/// Either-free.
enum PicartoFailureKind {
  /// No such channel: an HTTP 404, a detail whose `channel` is null, or a
  /// room id that is no Picarto channel name.
  notFound,

  /// The answer's shape changed under us: a body that is not JSON or too
  /// large, an explore page that does not echo its request, a channel answer
  /// of another name, a master playlist that is no playlist.
  apiChanged,

  /// The transport failed, or the site answered with a status no gate
  /// explains (5xx, a redirect).
  network,

  /// The site refused the session (HTTP 401 or 403).
  riskControl,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// Nothing to play: the channel is off the air or private (a private
  /// channel needs the streamer's private key).
  streamUnavailable,

  /// A request the caller got wrong: an area that is no Picarto area, a
  /// page or page size outside what the platform ever served.
  invalidArgument,
}

/// A Picarto platform failure.
final class PicartoFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const PicartoFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final PicartoFailureKind kind;

  /// Diagnostic text.
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary. The
  /// session refusal (401, 403) folds into the rate-limit error, as the
  /// contract's other adapters do.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    PicartoFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    PicartoFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    PicartoFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    PicartoFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    PicartoFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    PicartoFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
    PicartoFailureKind.invalidArgument => LiveSiteError.invalidArgument(siteId: siteId, message: message),
  };

  /// Whether asking again could mend this: only a transport breakdown or a
  /// throttle can, so a caller that is about to keep trying does not spend a
  /// request on a channel that is gone or a stream that is over — an edge
  /// refusal does not lift on retry.
  bool get isTransient => kind == PicartoFailureKind.network || kind == PicartoFailureKind.rateLimited;

  @override
  String toString() => 'PicartoFailure(${kind.name}: $message)';
}
