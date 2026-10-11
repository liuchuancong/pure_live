import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_playback/src/model/playback_failure.dart';

part 'playback_state.freezed.dart';

/// Where a playback session currently stands.
enum PlaybackPhase {
  /// Nothing loaded yet.
  idle,

  /// Qualities and lines are being resolved.
  resolving,

  /// A line is being opened by the engine.
  opening,

  /// Playing.
  playing,

  /// Paused by the user.
  paused,

  /// Recovering after a failure.
  recovering,

  /// Stopped for good (the room is not live, or the ladder gave up).
  ended,
}

/// The immutable state of one playback session.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class PlaybackState with _$PlaybackState {
  /// A state snapshot.
  const factory PlaybackState({
    @Default(PlaybackPhase.idle) PlaybackPhase phase,

    /// The label of the quality being played.
    String? qualityLabel,

    /// The id of the line being played.
    String? lineId,

    /// How many recovery attempts have been spent.
    @Default(0) int recoveryAttempts,

    /// The failure that led to the current recovery, if any.
    PlaybackFailure? lastFailure,
  }) = _PlaybackState;

  const PlaybackState._();

  /// Whether the session is playing or paused.
  bool get isActive => phase == PlaybackPhase.playing || phase == PlaybackPhase.paused;

  /// Whether the session stopped for good.
  bool get isEnded => phase == PlaybackPhase.ended;

  /// Whether the session is working (resolving, opening, recovering).
  bool get isBusy =>
      phase == PlaybackPhase.resolving || phase == PlaybackPhase.opening || phase == PlaybackPhase.recovering;
}
