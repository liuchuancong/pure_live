import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_site_error.freezed.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// An expected failure at a capability boundary — a value, never a throw
/// (ARCHITECTURE.md §5).
///
/// 'message' is diagnostic text for logs and developers; it must never carry
/// tokens, cookies or signed URLs, and user-facing wording is the
/// application's business. 'cause' keeps the original error for diagnosis
/// only.
@freezed
sealed class LiveSiteError with _$LiveSiteError {
  const factory LiveSiteError.notFound({required String siteId, required String message}) = LiveSiteNotFound;

  const factory LiveSiteError.unsupported({required String siteId, required String message}) = LiveSiteUnsupported;

  const factory LiveSiteError.network({required String siteId, required String message, Object? cause}) =
      LiveSiteNetworkError;

  const factory LiveSiteError.parse({required String siteId, required String message, Object? cause}) =
      LiveSiteParseError;

  const factory LiveSiteError.authentication({required String siteId, required String message}) =
      LiveSiteAuthenticationError;

  const factory LiveSiteError.rateLimit({required String siteId, required String message}) = LiveSiteRateLimitError;

  /// The content itself is not available (a live room on air that pushes no
  /// stream, a withdrawn media) — a room state, not a transport or shape
  /// failure.
  const factory LiveSiteError.contentUnavailable({required String siteId, required String message}) =
      LiveSiteContentUnavailable;

  const factory LiveSiteError.invalidArgument({required String siteId, required String message}) =
      LiveSiteInvalidArgument;

  const factory LiveSiteError.unexpected({required String siteId, required String message, Object? cause}) =
      LiveSiteUnexpectedError;
}
