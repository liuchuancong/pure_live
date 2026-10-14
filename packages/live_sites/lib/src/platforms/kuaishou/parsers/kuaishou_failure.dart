import 'package:live_sites/src/core/live_site_error.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What went wrong inside the kuaishou platform, as the parsers throw it.
///
/// Parsers and the HTTP wrapper throw these; the capability implementations
/// map them onto [LiveSiteError] values at the Either boundary
/// (ARCHITECTURE.md §5) — inside the platform they stay exceptions so the
/// pure parsing code stays Either-free.
enum KuaishouFailureKind {
  /// The address names no room (`errorType` 22, an empty or malformed id).
  notFound,

  /// The answer's shape changed under us (a missing `data`, a missing `list`,
  /// a page without `__INITIAL_STATE__`, a body that is not JSON).
  apiChanged,

  /// The transport failed (timeout, connection, HTTP 5xx).
  network,

  /// The edge throttled us (`result` 2, "操作太快了", or HTTP 429).
  rateLimited,

  /// Kuaishou's risk control: `result` 10 (the guest gate, "服务器繁忙"), a
  /// verification page, an `errorType` other than 22, or a 401/403.
  riskControl,

  /// The room has no playable stream for this client (offline, or a page that
  /// says living but hands this client no quality).
  streamUnavailable,
}

/// A kuaishou platform failure.
final class KuaishouFailure implements Exception {
  /// A failure of [kind]; [message] is diagnostic text without secrets.
  const KuaishouFailure(this.kind, this.message, {this.cause});

  /// What went wrong.
  final KuaishouFailureKind kind;

  /// Diagnostic text (no tokens, cookies or signed URLs).
  final String message;

  /// The underlying error, when there was one.
  final Object? cause;

  /// The Either-side error this maps to at the capability boundary.
  LiveSiteError toLiveSiteError(String siteId) => switch (kind) {
    KuaishouFailureKind.notFound => LiveSiteError.notFound(siteId: siteId, message: message),
    KuaishouFailureKind.apiChanged => LiveSiteError.parse(siteId: siteId, message: message, cause: cause),
    KuaishouFailureKind.network => LiveSiteError.network(siteId: siteId, message: message, cause: cause),
    KuaishouFailureKind.rateLimited => LiveSiteError.rateLimit(siteId: siteId, message: message),
    KuaishouFailureKind.riskControl => LiveSiteError.rateLimit(siteId: siteId, message: message),
    KuaishouFailureKind.streamUnavailable => LiveSiteError.contentUnavailable(siteId: siteId, message: message),
  };

  @override
  String toString() => 'KuaishouFailure(${kind.name}: $message)';
}
