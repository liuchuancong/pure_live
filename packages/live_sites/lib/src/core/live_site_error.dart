// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:meta/meta.dart';

/// An expected failure at a capability boundary — a value, never a throw
/// (ARCHITECTURE.md §5).
///
/// 'message' is diagnostic text for logs and developers; it must never carry
/// tokens, cookies or signed URLs, and user-facing wording is the
/// application's business. 'cause' keeps the original error for diagnosis
/// only. Hand-written sealed, not built_value: the nine-way union is what
/// pattern matching wants, and it never persists.
@immutable
sealed class LiveSiteError {
  const LiveSiteError._(this.siteId, this.message, this.cause);

  /// Creates a LiveSiteError with already-normalized fields.
  const factory LiveSiteError.notFound({required String siteId, required String message}) = LiveSiteNotFound;

  /// Creates a LiveSiteError with already-normalized fields.
  const factory LiveSiteError.unsupported({required String siteId, required String message}) = LiveSiteUnsupported;

  /// Creates a LiveSiteError with already-normalized fields.
  const factory LiveSiteError.network({required String siteId, required String message, Object? cause}) =
      LiveSiteNetworkError;

  /// Creates a LiveSiteError with already-normalized fields.
  const factory LiveSiteError.parse({required String siteId, required String message, Object? cause}) =
      LiveSiteParseError;

  /// Creates a LiveSiteError with already-normalized fields.
  const factory LiveSiteError.authentication({required String siteId, required String message}) =
      LiveSiteAuthenticationError;

  /// Creates a LiveSiteError with already-normalized fields.
  const factory LiveSiteError.rateLimit({required String siteId, required String message}) = LiveSiteRateLimitError;

  /// The content itself is not available (a live room on air that pushes no
  /// stream, a withdrawn media) — a room state, not a transport or shape
  /// failure.
  const factory LiveSiteError.contentUnavailable({required String siteId, required String message}) =
      LiveSiteContentUnavailable;

  /// Creates a LiveSiteError with already-normalized fields.
  const factory LiveSiteError.invalidArgument({required String siteId, required String message}) =
      LiveSiteInvalidArgument;

  /// Creates a LiveSiteError with already-normalized fields.
  const factory LiveSiteError.unexpected({required String siteId, required String message, Object? cause}) =
      LiveSiteUnexpectedError;

  /// The site that failed.
  final String siteId;

  /// Diagnostic text for logs and developers.
  final String message;

  /// The original error, for diagnosis only; null on the variants that
  /// never carry one.
  final Object? cause;

  @override
  // The variant's own name is the useful part of the prefix.
  // ignore: no_runtimetype_tostring
  String toString() => '$runtimeType($siteId, $message)';
}

/// The room or resource was not found.
@immutable
final class LiveSiteNotFound extends LiveSiteError {
  /// A not-found failure.
  const LiveSiteNotFound({required String siteId, required String message}) : super._(siteId, message, null);

  @override
  bool operator ==(Object other) => other is LiveSiteNotFound && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}

/// The site does not support the capability asked of it.
@immutable
final class LiveSiteUnsupported extends LiveSiteError {
  /// An unsupported-capability failure.
  const LiveSiteUnsupported({required String siteId, required String message}) : super._(siteId, message, null);

  @override
  bool operator ==(Object other) => other is LiveSiteUnsupported && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}

/// The transport failed.
@immutable
final class LiveSiteNetworkError extends LiveSiteError {
  /// A network failure.
  const LiveSiteNetworkError({required String siteId, required String message, Object? cause})
    : super._(siteId, message, cause);

  @override
  bool operator ==(Object other) => other is LiveSiteNetworkError && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}

/// The response's shape broke the adapter's expectations.
@immutable
final class LiveSiteParseError extends LiveSiteError {
  /// A parse failure.
  const LiveSiteParseError({required String siteId, required String message, Object? cause})
    : super._(siteId, message, cause);

  @override
  bool operator ==(Object other) => other is LiveSiteParseError && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}

/// The request needs credentials the site does not hold.
@immutable
final class LiveSiteAuthenticationError extends LiveSiteError {
  /// An authentication failure.
  const LiveSiteAuthenticationError({required String siteId, required String message}) : super._(siteId, message, null);

  @override
  bool operator ==(Object other) =>
      other is LiveSiteAuthenticationError && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}

/// The platform throttled the request.
@immutable
final class LiveSiteRateLimitError extends LiveSiteError {
  /// A rate-limit failure.
  const LiveSiteRateLimitError({required String siteId, required String message}) : super._(siteId, message, null);

  @override
  bool operator ==(Object other) =>
      other is LiveSiteRateLimitError && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}

/// The content itself is not available.
@immutable
final class LiveSiteContentUnavailable extends LiveSiteError {
  /// A content-unavailable failure.
  const LiveSiteContentUnavailable({required String siteId, required String message}) : super._(siteId, message, null);

  @override
  bool operator ==(Object other) =>
      other is LiveSiteContentUnavailable && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}

/// The caller's arguments were invalid.
@immutable
final class LiveSiteInvalidArgument extends LiveSiteError {
  /// An invalid-argument failure.
  const LiveSiteInvalidArgument({required String siteId, required String message}) : super._(siteId, message, null);

  @override
  bool operator ==(Object other) =>
      other is LiveSiteInvalidArgument && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}

/// Anything the adapter could not classify.
@immutable
final class LiveSiteUnexpectedError extends LiveSiteError {
  /// An unclassified failure.
  const LiveSiteUnexpectedError({required String siteId, required String message, Object? cause})
    : super._(siteId, message, cause);

  @override
  bool operator ==(Object other) =>
      other is LiveSiteUnexpectedError && other.siteId == siteId && other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message);
}
