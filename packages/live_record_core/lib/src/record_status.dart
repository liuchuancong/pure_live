/// The four state axes a recording is described by.
///
/// They are separate enums because they answer different questions and change at
/// different rates, and folding them into one status is what makes a recorder
/// unable to tell "the room is not up yet" from "the files are still unmerged":
///
/// - [ProbeOutcome] is what the platform's own API said, and nothing more.
/// - [RoomState] is what this package concluded from it across polls, and it is
///   what decides whether to record and whether to tell the viewer.
/// - [RecordStatus] is where the task sits in the queue and the process, and it
///   decides whether the task can be started again.
/// - [ArtifactStage] is what the files on disk still owe, and it is the whole
///   basis for finishing a recording after a power loss or a network cut.
library;

/// What a room's status endpoint answered about the room right now.
///
/// Deliberately minimal: a platform API reports "living" or "not", and it cannot
/// distinguish a streamer who has not started yet from one who just stopped —
/// that distinction is not the endpoint's to make, so it is made in [RoomState]
/// from what this package saw on the previous poll.
enum ProbeOutcome {
  /// The room is broadcasting.
  live,

  /// The room is not broadcasting, and there is no reason to think it went away.
  offline,

  /// The room cannot be reached: deleted, banned, or a bad address. Retrying
  /// forever is not a plan, so the task stops rather than waiting.
  unavailable,

  /// The probe itself failed (network, parsing, rate limit). Nothing is concluded
  /// about the room, and the wait before the next probe follows the failure path
  /// rather than the ordinary one.
  unknown,
}

/// What this package concluded about the room, across polls.
enum RoomState {
  /// Nothing has been asked yet.
  unknown,

  /// The room has not been seen live in this session, and is expected to
  /// broadcast later: keep watching, record nothing, notify nobody.
  waiting,

  /// Broadcasting. This is when a capture runs.
  live,

  /// Was seen live in this session and is not live now.
  ///
  /// The only difference from [waiting] is the one a viewer cares about: an
  /// ended broadcast has files that need finishing and deserves the "直播已结束"
  /// message, while a room that never started deserves neither. It is derived
  /// from the first [live] answer plus a later non-live one, because the status
  /// endpoint cannot tell you it.
  ended,

  /// The endpoint still answers live while no media advances — a stream kept
  /// alive by nothing. The capture is ended and joined rather than left open,
  /// and the wait before the next probe shortens.
  stalled,

  /// The room is gone [ProbeOutcome.unavailable].
  unavailable,
}

/// Whether the room is up: [RoomState.live] or [RoomState.stalled].
bool roomIsUp(RoomState state) => state == RoomState.live || state == RoomState.stalled;

/// Where the task itself is.
///
/// Only [recording] and [retrying] hold a capture process; only [recording],
/// [retrying], [merging] and [queued] hold a slot in the concurrency limit.
enum RecordStatus {
  /// Accepted, waiting for a free capture slot.
  queued,

  /// Resolving the room and the stream address before capturing.
  resolving,

  /// Capturing media.
  recording,

  /// A capture ended unexpectedly and another one is being arranged. The room is
  /// still live, so nothing on disk is finished or joined yet.
  retrying,

  /// Joining the recorded segments into one file.
  merging,

  /// Recorded, joined and named. Nothing further is owed.
  completed,

  /// Ended without a usable recording, and not retrying.
  failed,

  /// Ended by the user or by the host.
  stopped,

  /// A previous run left this task in the store with work still owed: unjoined
  /// segments, a merged file that has not been given its display name, or a
  /// capture that was still running when the process died.
  ///
  /// Set by the recovery sweep at open, and it is what lets "the power went out
  /// while recording" resolve into a finished file on the next launch instead of
  /// a folder of loose segments nobody touches.
  interrupted,
}

/// Whether the task still occupies the process or a slot.
bool statusIsBusy(RecordStatus status) =>
    status == RecordStatus.queued ||
    status == RecordStatus.resolving ||
    status == RecordStatus.recording ||
    status == RecordStatus.retrying ||
    status == RecordStatus.merging;

/// Whether the task is over and will not advance by itself.
bool statusIsTerminal(RecordStatus status) =>
    status == RecordStatus.completed || status == RecordStatus.failed || status == RecordStatus.stopped;

/// What the files on disk still owe.
enum ArtifactStage {
  /// Nothing has been captured.
  nothing,

  /// A capture is writing segments now.
  capturing,

  /// Segments exist on disk that have not been joined into one file.
  ///
  /// This is the state a crash or a pulled network cable leaves behind, and the
  /// reason the list of attempts is persisted: the segments are playable, but a
  /// folder of twelve of them is not the recording the user asked for.
  unmergedSegments,

  /// Joined into one file, still under the capture-safe ASCII name.
  mergedFile,

  /// Given its display name. The recording is finished from the viewer's side.
  published,

  /// The files were deliberately discarded (a cancelled capture, or a merge that
  /// refused to run against damaged packets and left nothing worth keeping).
  dropped,
}
