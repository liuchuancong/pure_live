// Module: lib/src/domain/recording_task.dart
// Purpose: The recording task model: a stream ref, its file target, and the
// state machine idle -> recording -> stopped | failed.
// Author: liuchuancong
// Created: 2026-10-10
//
// The engine wiring (ffmpeg_kit / media_core recording) is the data layer's
// job and lands with the recorder wave; this model is the state contract the
// UI and the task list consume, so a recording's lifecycle is correct even
// before the encoder exists.

import 'package:pure_live_platform/pure_live_platform.dart';

/// The lifecycle states of one recording.
enum RecordingState { idle, recording, stopped, failed }

/// Why a recording stopped or failed.
enum RecordingEndReason { none, userStopped, streamEnded, diskFull, encoderError }

/// One recording task.
final class RecordingTask {
  RecordingTask({required this.ref, required this.fileName, DateTime? startedAt})
    : id =
          '${ref.sourceId}/${ref.contentId}-${startedAt?.millisecondsSinceEpoch ?? DateTime.now().toUtc().millisecondsSinceEpoch}',
      startedAt = startedAt ?? DateTime.now().toUtc();

  /// Stable id: source/room plus the start stamp.
  final String id;
  final ContentRef ref;

  /// The output file name the host's recorder writes to.
  final String fileName;

  final DateTime startedAt;

  RecordingState state = RecordingState.idle;
  RecordingEndReason endReason = RecordingEndReason.none;

  DateTime? _stoppedAt;
  DateTime? get stoppedAt => _stoppedAt;

  Duration get elapsed => (_stoppedAt ?? DateTime.now().toUtc()).difference(startedAt);

  bool get isRecording => state == RecordingState.recording;

  /// Marks the recording as actively writing. Only valid from idle.
  bool start() {
    if (state != RecordingState.idle) {
      return false;
    }
    state = RecordingState.recording;
    return true;
  }

  /// Marks the recording stopped for [reason]. Terminal: further transitions
  /// are refused so a late encoder callback cannot resurrect a finished task.
  bool stop(RecordingEndReason reason) {
    if (state != RecordingState.recording) {
      return false;
    }
    state = RecordingState.stopped;
    endReason = reason;
    _stoppedAt = DateTime.now().toUtc();
    return true;
  }

  /// Marks the recording failed. Terminal like [stop].
  bool fail(RecordingEndReason reason) {
    if (state != RecordingState.recording) {
      return false;
    }
    state = RecordingState.failed;
    endReason = reason;
    _stoppedAt = DateTime.now().toUtc();
    return true;
  }
}
