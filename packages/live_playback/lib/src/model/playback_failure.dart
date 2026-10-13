import 'package:freezed_annotation/freezed_annotation.dart';

part 'playback_failure.freezed.dart';

/// Why a playback attempt failed, classified for the recovery ladder.
///
/// The classifier maps site errors and engine events into these kinds;
/// the ladder decides purely from the kind what to try next, so engine
/// specifics never leak into the recovery policy.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
sealed class PlaybackFailure with _$PlaybackFailure implements Exception {
  /// The stream URL is dead (expired lease, 404, stream gone).
  const factory PlaybackFailure.streamUnavailable({
    /// Human-readable detail.
    required String detail,
  }) = StreamUnavailableFailure;

  /// The room is not broadcasting right now.
  const factory PlaybackFailure.notLive({
    /// Human-readable detail.
    required String detail,
  }) = NotLiveFailure;

  /// The platform needs a login this session cannot provide.
  const factory PlaybackFailure.needsLogin({
    /// Human-readable detail.
    required String detail,
  }) = NeedsLoginFailure;

  /// The platform rate-limited or risk-controlled the request.
  const factory PlaybackFailure.rateLimited({
    /// Human-readable detail.
    required String detail,
  }) = RateLimitedFailure;

  /// The transport broke down (network, TLS, timeout).
  const factory PlaybackFailure.network({
    /// Human-readable detail.
    required String detail,
  }) = NetworkFailure;

  /// The engine failed while playing a line it had opened.
  const factory PlaybackFailure.engine({
    /// Human-readable detail.
    required String detail,

    /// The underlying error, when one is available.
    Object? cause,
  }) = EngineFailure;

  /// A platform change the adapter cannot parse.
  const factory PlaybackFailure.apiChanged({
    /// Human-readable detail.
    required String detail,
  }) = ApiChangedFailure;
}

/// Classification of failures for the ladder.
extension PlaybackFailureKind on PlaybackFailure {
  /// Whether retrying (or advancing the ladder) can plausibly help.
  ///
  /// A not-live room and a login requirement never recover by retrying;
  /// a dead URL, a network hiccup or an engine stall usually does.
  bool get isRetryable => switch (this) {
    StreamUnavailableFailure() || NetworkFailure() || EngineFailure() || RateLimitedFailure() => true,
    NotLiveFailure() || NeedsLoginFailure() || ApiChangedFailure() => false,
  };

  /// Whether the ladder should advance to another line or quality.
  bool get shouldAdvanceLadder => isRetryable;
}
