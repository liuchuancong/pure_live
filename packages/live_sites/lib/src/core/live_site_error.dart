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
  ///
  /// [cookieSuspect] tells the app the stored login was refused rather than
  /// missing, which is the difference between sending the viewer to the account
  /// page and waiting for them to log in.
  const factory LiveSiteError.authentication({required String siteId, required String message, bool? cookieSuspect}) =
      LiveSiteAuthenticationError;

  /// Creates a LiveSiteError with already-normalized fields.
  ///
  /// [retryAfter] is the platform's own wait, in seconds, when it names one.
  const factory LiveSiteError.rateLimit({required String siteId, required String message, Duration? retryAfter}) =
      LiveSiteRateLimitError;

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

  /// Whether asking the platform the same thing again later can succeed.
  ///
  /// The recovery logic branches on this and on nothing else. A transport that
  /// blinked or a platform that throttled one request is worth another attempt;
  /// a room that does not exist, a capability the site never had, a body that
  /// broke the spec — retrying those only spends the viewer's data and, on a
  /// throttled site, the quota the next real request needs. A temporary failure
  /// treated as a permanent one also ends a recording that would have carried on.
  bool get isTransient => false;

  /// How long the platform asked to be left alone, when it said.
  ///
  /// Null on every variant that cannot be told, and on a rate limit that gave
  /// no hint; a caller waiting on one picks its own backoff instead.
  Duration? get retryAfter => null;

  /// Whether the login the viewer stored is the likely cause.
  ///
  /// `true` says the answer belongs in the account page — the cookie has to be
  /// renewed — rather than in the room, where nothing the viewer can do will
  /// make the platform answer. A refused login and an absent one are different
  /// work, and a hint that asks for the second when the first is broken is a
  /// hint the viewer follows twice for nothing.
  bool get cookieSuspect => false;

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

  /// The transport blinked; asking again is how a live room stays up.
  @override
  bool get isTransient => true;

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
  ///
  /// [cookieSuspect] says the credentials the app does hold were refused — an
  /// expiry, a bad signature — rather than that none were ever given.
  const LiveSiteAuthenticationError({required String siteId, required String message, bool? cookieSuspect})
    : _cookieSuspect = cookieSuspect ?? false,
      super._(siteId, message, null);

  final bool _cookieSuspect;

  /// The base class's [LiveSiteError.cookieSuspect]: this site was handed a
  /// login and said no to it.
  @override
  bool get cookieSuspect => _cookieSuspect;

  @override
  bool operator ==(Object other) =>
      other is LiveSiteAuthenticationError &&
      other.siteId == siteId &&
      other.message == message &&
      other.cookieSuspect == cookieSuspect;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message, cookieSuspect);
}

/// The platform throttled the request.
@immutable
final class LiveSiteRateLimitError extends LiveSiteError {
  /// A rate-limit failure.
  const LiveSiteRateLimitError({required String siteId, required String message, this.retryAfter})
    : super._(siteId, message, null);

  /// How long the platform said, when its answer said anything.
  @override
  final Duration? retryAfter;

  /// Throttled now is not refused forever; the wait is what differs.
  @override
  bool get isTransient => true;

  @override
  bool operator ==(Object other) =>
      other is LiveSiteRateLimitError &&
      other.siteId == siteId &&
      other.message == message &&
      other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(runtimeType, siteId, message, retryAfter);
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
