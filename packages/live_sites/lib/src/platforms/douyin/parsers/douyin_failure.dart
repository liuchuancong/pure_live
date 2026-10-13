import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the douyin platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum DouyinFailureKind {
  /// The address names no room (a dead web_rid, status_code 4001038, a page
  /// without the room state).
  notFound,

  /// The answer's shape changed under us.
  apiChanged,

  /// The transport failed (timeout, connection, 5xx).
  network,

  /// The operation needs a login that is not there (status_code 2483 login
  /// search, 20003 account).
  needsLogin,

  /// The edge throttled us (HTTP 429).
  rateLimited,

  /// The edge refused the client: a captcha (`bdturing-verify`), a bare
  /// 401/403, or an empty 200 (no ttwid, a rejected signature).
  riskControl,

  /// The room is on air but its `stream_url` offers no video for this
  /// client (audio-only or no stream at all).
  streamUnavailable,
}

/// A douyin platform failure.
final class DouyinFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const DouyinFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final DouyinFailureKind kind;

  /// Diagnostic text (no secrets).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    DouyinFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    DouyinFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    DouyinFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    DouyinFailureKind.needsLogin => LiveSiteError.authentication(siteId: siteId, message: message),
    DouyinFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    DouyinFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    DouyinFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'DouyinFailure(${kind.name}: $message)';
}
