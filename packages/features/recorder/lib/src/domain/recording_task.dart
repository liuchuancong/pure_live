// Module: lib/src/domain/recording_task.dart
// Purpose: The lifecycle of one recording: what stream, where it writes, and which state transitions exist.
// Author: liuchuancong
// Created: 2026-10-10
//
// The engine wiring (ffmpeg_kit / media_core) is the data layer's job and lands with the recorder wave; this
// model is the contract the UI and the task list consume, so a recording's lifecycle is already correct
// before the encoder exists. It was not, in three ways worth naming:
//
// 1. `state` and `endReason` were public writable fields. The class comment promised "a late encoder callback
//    cannot resurrect a finished task", and the line below it let any caller assign `recording` to the field.
// 2. A task in `idle` reported an `elapsed` that grew with wall-clock time, so a queued recording looked like
//    it had been running for an hour - the one number the list screen shows.
// 3. `fileName` went to the host's output path unchecked, the same way the backup snapshot name used to, so a
//    name with a separator addressed outside the recording directory.
//
// Transitions are now methods returning the next value, the clock is injected so a test can pin durations,
// and an end reason is required where one exists.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// The lifecycle states of one recording.
enum RecordingState { queued, recording, stopped, failed }

/// Why a recording left the recording state.
enum RecordingEndReason { userStopped, streamEnded, diskFull, encoderError, engineLost }

/// Why an operation on a recording could not be carried out.
final class RecordingFailure extends DomainFailure {
  const RecordingFailure(super.reason, {super.cause});
}

/// One recording, from the moment it was created to the moment it ended.
final class RecordingTask with ValueEquality {
  /// A recording waiting to start. [startedAt] is when it was created; the clock only starts counting on
  /// [begin].
  RecordingTask({required this.ref, required String fileName, Clock? clock, DateTime? createdAt})
    : _clock = clock ?? systemClock,
      fileName = requireSafeFileName(fileName),
      createdAt = (createdAt ?? (clock ?? systemClock)()).toUtc(),
      beganAt = null,
      state = RecordingState.queued,
      endReason = null,
      stoppedAt = null;

  RecordingTask._({
    required this.ref,
    required this.fileName,
    required this.createdAt,
    required this.beganAt,
    required this.state,
    required this.endReason,
    required this.stoppedAt,
    required Clock clock,
  }) : _clock = clock;

  /// Stable identity: the content reference plus the creation stamp, length-prefixed so a contentId
  /// containing a separator cannot make two recordings share one id.
  String get id => identityKey(<Object?>[ref.sourceId, ref.contentId, createdAt.toIso8601String()]);

  final ContentRef ref;

  /// The output file name the host's recorder writes to. A name only: no separators, no parent references,
  /// because the host joins it onto its recording directory and that join is the last place a path can be
  /// constrained.
  final String fileName;

  /// When this recording was created, UTC. It never changes, so a task list keyed by [id] keeps the same
  /// key through every transition.
  final DateTime createdAt;

  /// When the recorder actually started writing, UTC; null while queued.
  final DateTime? beganAt;

  final RecordingState state;

  /// Set exactly when [state] is terminal, and null while it is not. The previous representation used a
  /// `none` enum member, which let "stopped for no reason" be written down.
  final RecordingEndReason? endReason;

  /// When it left the recording state, UTC; null while queued or recording.
  final DateTime? stoppedAt;

  final Clock _clock;

  bool get isQueued => state == RecordingState.queued;

  bool get isRecording => state == RecordingState.recording;

  bool get isTerminal => state == RecordingState.stopped || state == RecordingState.failed;

  /// How long the recording actually wrote.
  ///
  /// Zero while queued: a list screen showing a growing number for something that never started is worse
  /// than showing nothing, because it reads as "still going".
  Duration get elapsed {
    final began = beganAt;
    if (began == null) {
      return Duration.zero;
    }
    final ended = stoppedAt;
    return (ended == null ? _clock() : ended).difference(began);
  }

  /// The state a recorder writes into when it begins producing.
  RecordingTask begin() {
    if (state != RecordingState.queued) {
      throw RecordingFailure(
        state == RecordingState.recording
            ? 'recording $fileName is already writing'
            : 'recording $fileName ended (${_reasonName}) and cannot be started again',
      );
    }
    return RecordingTask._(
      ref: ref,
      fileName: fileName,
      createdAt: createdAt,
      beganAt: _clock().toUtc(),
      state: RecordingState.recording,
      endReason: null,
      stoppedAt: null,
      clock: _clock,
    );
  }

  /// The state after the recorder wrote its last byte because the user or the stream ended it.
  RecordingTask stop(RecordingEndReason reason) => _end(RecordingState.stopped, reason);

  /// The state after the recorder could not continue.
  RecordingTask fail(RecordingEndReason reason) => _end(RecordingState.failed, reason);

  RecordingTask _end(RecordingState next, RecordingEndReason reason) {
    if (state != RecordingState.recording) {
      throw RecordingFailure(
        state == RecordingState.queued
            ? 'recording $fileName never started, so it cannot '
                  '${next == RecordingState.stopped ? 'stop' : 'fail'}'
            : 'recording $fileName already ended (${_reasonName}); a late callback cannot change that',
      );
    }
    if (reason == RecordingEndReason.userStopped && next == RecordingState.failed) {
      throw RecordingFailure('a user stop is not a failure; report it with stop()');
    }
    return RecordingTask._(
      ref: ref,
      fileName: fileName,
      createdAt: createdAt,
      beganAt: beganAt,
      state: next,
      endReason: reason,
      stoppedAt: _clock().toUtc(),
      clock: _clock,
    );
  }

  String get _reasonName => endReason?.name ?? 'no reason';

  @override
  List<Object?> get equalityFields => <Object?>[id, state, endReason, stoppedAt];

  @override
  String toString() => 'RecordingTask($fileName $state${endReason == null ? '' : '/${endReason!.name}'})';
}

/// Validates [raw] as a file name that cannot escape the directory it is joined onto.
///
/// Exported because the host's own import path (a file the user picked) meets the same rule.
String requireSafeFileName(String raw) {
  final name = requireNonBlank(raw, name: 'fileName');
  if (name.contains('/') || name.contains(r'\') || name.contains('..') || name.codeUnits.any((unit) => unit < 0x20)) {
    throw RecordingFailure('"$raw" cannot be a recording file name: it would leave the recording directory');
  }
  return name;
}
