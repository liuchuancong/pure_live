import 'dart:async';

import 'package:live_record_core/src/record_status.dart';
import 'package:live_record_core/src/record_task.dart';

/// What a room's own endpoint answered.
///
/// [streamUrl] is runtime-only and must never be persisted: it is a signed
/// address, it expires, and a task file that kept one would leak a credential and
/// then fail on the next launch with an error that says nothing about either.
final class RoomProbe {
  /// Creates a probe answer.
  const new({required this.outcome, this.streamUrl, this.roomTitle, this.anchorName, this.detail, this.checkedAt});

  /// What was said about the room.
  final ProbeOutcome outcome;

  /// The address to capture, when the room is up.
  final String? streamUrl;

  /// Current room title, for the display name.
  final String? roomTitle;

  /// Anchor name, when the endpoint knows it and the task does not yet.
  final String? anchorName;

  /// Why it is unavailable, or what the endpoint said on a failure.
  final String? detail;

  /// When the answer was produced; defaults to the caller's clock.
  final DateTime? checkedAt;

  /// Whether the room can be captured right now.
  bool get isCaptureable => outcome == ProbeOutcome.live && (streamUrl?.isNotEmpty ?? false);
}

/// Progress a running capture reports.
final class RecordProgress {
  /// Creates a progress report.
  const new({required this.mediaTime, required this.bytes, required this.segments});

  /// Media time written.
  final Duration mediaTime;

  /// Bytes on disk.
  final int bytes;

  /// Segments the journal has listed.
  final int segments;

  @override
  String toString() => 'RecordProgress(${mediaTime.inSeconds}s, $bytes B, $segments segments)';
}

/// What one finished capture attempt left on disk.
final class CaptureOutcome {
  /// Creates an outcome.
  const new({
    required this.directory,
    required this.prefix,
    required this.segments,
    required this.bytes,
    required this.mediaTime,
    this.damaged = false,
    this.failure,
  });

  /// Directory the segments were written to.
  final String directory;

  /// The ASCII prefix they carry.
  final String prefix;

  /// Segments listed by the journal.
  final int segments;

  /// Bytes measured from the files.
  final int bytes;

  /// Media time across the attempt.
  final Duration mediaTime;

  /// Damaged packets were reported while capturing.
  final bool damaged;

  /// Why the attempt ended badly, when it did. Nothing about the files is assumed:
  /// an attempt that wrote segments before it failed has segments worth joining.
  final String? failure;

  /// Whether anything usable was left.
  bool get hasMedia => segments > 0 && bytes > 0;

  /// The same facts as a persisted pending attempt.
  PendingAttempt toPendingAttempt() => PendingAttempt(
    directory: directory,
    prefix: prefix,
    segments: segments,
    bytes: bytes,
    mediaTime: mediaTime,
    damaged: damaged,
  );
}

/// One running capture.
///
/// Implemented by an adapter over `media_core_recording_ffmpeg`'s
/// `FfmpegRecordingBackend`: [stop] maps to the backend's `stop()`, whose result is
/// already a file-based verdict rather than an exit code, and [outcome] carries that
/// verdict here.
abstract interface class RecordCapture {
  /// Progress as the capture writes.
  Stream<RecordProgress> get onProgress;

  /// Completes when the capture ends on its own.
  ///
  /// This is the event that tells the kernel a broadcast is over: while a capture
  /// runs the room's status endpoint is deliberately not polled (the capture is the
  /// better instrument, and two timers watching one fact disagree), so without this
  /// an 下播 would be noticed only when the stall watchdog ran out its patience.
  Future<void> get ended;

  /// Ends the capture and settles its files.
  Future<void> stop();

  /// Ends the capture and discards what it wrote.
  Future<void> cancel();

  /// The attempt's result. Only meaningful once [stop] or [cancel] has returned.
  CaptureOutcome get outcome;
}

/// What a join of segments produced.
final class MergeOutcome {
  /// Creates a merge outcome.
  const new({required this.path, required this.bytes, required this.mediaTime, this.failure});

  /// The merged file, under its capture name.
  final String path;

  /// Its size.
  final int bytes;

  /// Its media time.
  final Duration mediaTime;

  /// Why the merge did not run, when it did not.
  final String? failure;

  /// Whether there is a file to publish.
  bool get isSuccess => failure == null;
}

/// What a display-name change produced.
final class RenameOutcome {
  /// Creates a rename outcome.
  const new({required this.applied, required this.path, this.failure});

  /// Whether the file now carries the name in [path].
  final bool applied;

  /// The resulting path — the requested one when [applied], the capture name when
  /// it did not happen.
  final String path;

  /// Why the rename failed.
  final String? failure;
}

/// The file layer the kernel drives.
///
/// [merge] joins one attempt's segments; an implementation maps it to
/// `FfmpegRecordingBackend.combineLastRecording()` or to the standalone
/// `FfmpegRecordingRemuxer` for a directory found after a crash. [rename] is the
/// only step allowed to introduce a non-ASCII path, because it runs after FFmpeg is
/// finished with the file.
abstract interface class RecordFiles {
  /// Joins [attempts] of [task] into one file.
  Future<MergeOutcome> merge({required RecordTask task, required List<PendingAttempt> attempts});

  /// Applies [to] to the file at [from].
  ///
  /// Must not throw and must not delete [from] on failure: the ASCII file is the
  /// recording, and a rename that cannot happen is a naming problem, not a data loss.
  Future<RenameOutcome> rename({required String from, required String to});

  /// Whether a path exists.
  Future<bool> exists(String path);

  /// Whether the directory holding the task's files still has room for more.
  Future<int?> freeBytes(String directory);
}

/// The screen-off protection: a foreground notification plus a wake lock.
///
/// Implemented over `media_core_native`'s `BackgroundExecution.acquire(wakeLock: true)`,
/// which on Android is the foreground service that keeps FFmpeg running when the
/// app is hidden and the screen is off. Without it a recording stops at the exact
/// moment a viewer stops watching — with the phone in their pocket — and the exit
/// code says nothing about why.
abstract interface class RecordGuard {
  /// Refreshes the line: the anchor, how long, how much.
  Future<void> update(RecordProgress progress);

  /// Releases the protection. Idempotent.
  Future<void> release();
}

/// Why the viewer is being told.
enum RecordNoticeKind {
  /// The room started broadcasting and recording began.
  liveStarted,

  /// The room stopped, and what was captured is finished.
  liveEnded,

  /// A recording is usable at its final name.
  recordingSaved,

  /// Segments were found that had never been joined, and now are.
  recovered,

  /// A task could not be completed.
  failed,
}

/// One message for the host's tray.
final class RecordNotice {
  /// Creates a notice.
  const new({required this.kind, required this.task, required this.text, this.detail});

  /// Which event this is.
  final RecordNoticeKind kind;

  /// The task it is about.
  final RecordTask task;

  /// The line to show. Composed by the kernel, because "录制完成 · 主播8891 · 12:03"
  /// is a statement about the recording, not a platform detail.
  final String text;

  /// Extra detail, usually a failure.
  final String? detail;
}

/// Everything the kernel needs from outside itself.
///
/// The app shell implements this once: [probe] from the site's own status endpoint
/// (`live_sites`), [openCapture] and [files] over `media_core_recording_ffmpeg`,
/// [acquireGuard] and [notify] over `media_core_native` (and `media_core_notify`
/// where a host uses it). This package depends on none of those, which is what keeps
/// the task ledger testable and free of an engine.
abstract interface class RecordServices {
  /// Asks the room what it is doing.
  Future<RoomProbe> probe(RecordTarget target);

  /// Opens a capture of [streamUrl] into [task]'s session directory, under its
  /// ASCII prefix.
  Future<RecordCapture> openCapture({required RecordTask task, required String streamUrl});

  /// Takes the screen-off protection for one recording, or null when the platform
  /// has nothing to hold. A null guard is not a failure: the recording runs, it just
  /// may not survive the screen going off.
  Future<RecordGuard?> acquireGuard({required RecordTask task});

  /// Tells the viewer. Must not throw and must not stall the caller.
  Future<void> notify(RecordNotice notice);

  /// The file layer.
  RecordFiles get files;
}
