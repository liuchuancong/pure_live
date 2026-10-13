// These error classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// A failure a platform adapter reports, by kind.
///
/// Sealed so the interface and the recovery logic handle each kind by type,
/// never by message text. An adapter returning an offline-looking room or a
/// human sentence instead lets a temporary error end a recording.
@immutable
sealed class SiteError implements Exception {
  /// Creates the failure for [site] with an optional diagnostic [detail].
  const SiteError(this.site, [this.detail]);

  /// Platform id, for example `douyu`.
  final String site;

  /// Diagnostic detail for logs; never shown as UI copy.
  final String? detail;

  /// Whether retrying the same request later can succeed.
  bool get isTransient => false;

  /// Stable name of the kind, for logs and diagnostics.
  String get kind;

  @override
  String toString() => '$kind($site${detail == null ? '' : ': $detail'})';
}

/// The room or streamer does not exist.
final class NotFound extends SiteError {
  /// Creates the error.
  const NotFound(super.site, [super.detail]);

  @override
  String get kind => 'NotFound';
}

/// The content needs a signed-in account.
final class NeedsLogin extends SiteError {
  /// Creates the error.
  const NeedsLogin(super.site, [super.detail]);

  @override
  String get kind => 'NeedsLogin';
}

/// The platform throttled the client.
final class RateLimited extends SiteError {
  /// Creates the error.
  const RateLimited(String site, {this.retryAfter, String? detail}) : super(site, detail);

  /// Suggested wait, when the platform gives one.
  final Duration? retryAfter;

  @override
  bool get isTransient => true;

  @override
  String get kind => 'RateLimited';
}

/// The platform refused the request as suspicious: a rejected signature, a
/// captcha, a stale cookie.
final class RiskControl extends SiteError {
  /// Creates the error.
  const RiskControl(String site, {this.cookieSuspect = false, String? detail}) : super(site, detail);

  /// Whether the user's stored cookie is the likely cause (ask to renew it).
  final bool cookieSuspect;

  @override
  String get kind => 'RiskControl';
}

/// The content is not available in the user's region.
final class RegionBlocked extends SiteError {
  /// Creates the error.
  const RegionBlocked(super.site, [super.detail]);

  @override
  String get kind => 'RegionBlocked';
}

/// No playable stream right now: offline, a loop or replay without a stream, or
/// live without video.
final class StreamUnavailable extends SiteError {
  /// Creates the error.
  const StreamUnavailable(super.site, [super.detail]);

  @override
  String get kind => 'StreamUnavailable';
}

/// A link that no adapter recognises.
final class UnsupportedLink extends SiteError {
  /// Creates the error.
  const UnsupportedLink(super.site, [super.detail]);

  @override
  String get kind => 'UnsupportedLink';
}

/// The response does not match the platform spec.
final class ApiChanged extends SiteError {
  /// Creates the error; [detail] should summarise the unexpected shape.
  const ApiChanged(super.site, [super.detail]);

  @override
  String get kind => 'ApiChanged';
}

/// The network failed before the platform answered.
final class NetworkFailure extends SiteError {
  /// Creates the error.
  const NetworkFailure(super.site, [super.detail]);

  @override
  bool get isTransient => true;

  @override
  String get kind => 'NetworkFailure';
}
