import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_playback/src/model/playback_failure.dart';

part 'playback_event.freezed.dart';

/// Diagnostics events a session emits.
///
/// These are for logging and UI diagnostics only — the state itself
/// travels through the session state and its listener.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class PlaybackEvent with _$PlaybackEvent {
  /// A line was opened and playback began.
  const factory PlaybackEvent.started({
    /// The quality label.
    required String quality,

    /// The line id, when the line has one.
    String? lineId,
  }) = PlaybackStarted;

  /// A failure was classified.
  const factory PlaybackEvent.failed({
    /// The classified failure.
    required PlaybackFailure failure,
  }) = PlaybackFailed;

  /// The ladder advanced to another line or quality.
  const factory PlaybackEvent.recovered({
    /// The quality the ladder moved to.
    required String quality,

    /// The attempt number (1-based).
    required int attempt,
  }) = PlaybackRecovered;

  /// The lease of the current line is being renewed proactively.
  const factory PlaybackEvent.renewing({
    /// The line being renewed.
    required String quality,
  }) = PlaybackRenewing;

  /// The session gave up (the ladder ran out or recovery is impossible).
  const factory PlaybackEvent.gaveUp({
    /// Why.
    required PlaybackFailure failure,
  }) = PlaybackGaveUp;
}
