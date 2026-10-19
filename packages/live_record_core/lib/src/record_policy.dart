import 'package:live_record_core/live_record_core.dart' show RecordFiles;

import 'package:live_record_core/src/record_services.dart' show RecordFiles;

import 'package:live_record_core/src/record_status.dart';

/// How long a recording session should be waited for, retried and re-probed.
///
/// The numbers are the ones a live room tolerates rather than defaults invented
/// here: a room's schedule is measured in tens of minutes, so polling faster only
/// buys the platform's rate limits, while a dropped connection has to be re-asked
/// within seconds or the beginning of the real session is lost.
///
/// The fields the recorder settings edit are deliberately mutable: the host
/// writes the new answer into the live policy, and the next scheduling decision
/// reads it — a re-created orchestrator would stop the recordings that are
/// running. Reads all happen at decision time, never at construction.
final class RecordPolicy {
  /// Creates a policy.
  new({
    this.maxConcurrent = 2,
    this.pollInterval = const Duration(seconds: 60),
    this.pollJitter = const Duration(seconds: 20),
    this.retryInterval = const Duration(seconds: 15),
    this.recheckInterval = const Duration(milliseconds: 300),
    this.maxProbeFailures = 5,
    this.maxCaptureFailures = 3,
    this.stallTimeout = const Duration(seconds: 45),
    this.minUsefulRecording = const Duration(seconds: 20),
    this.diskFloorBytes = 200 * 1024 * 1024,
    this.notifyOnRecovered = true,
    this.renameAfterMerge = true,
    this.enablePolling = true,
    this.pollBackoff = false,
    this.maxPollInterval = const Duration(minutes: 10),
  });

  /// How many rooms may be capturing at once. Each one is an FFmpeg process plus
  /// the relay behind it; a phone does not have many of those.
  int maxConcurrent;

  /// Ordinary wait between room checks, before jitter.
  Duration pollInterval;

  /// Extra random wait added to [pollInterval], so N watched rooms do not reach the
  /// platform's endpoint in the same second and trip its risk control.
  Duration pollJitter;

  /// Wait after a capture died unexpectedly while the room was still live.
  Duration retryInterval;

  /// Wait after a recording that ended almost immediately. A streamer restarting
  /// their encoder looks exactly like a room that closed, and waiting the full
  /// [pollInterval] there costs the beginning of the real session.
  Duration recheckInterval;

  /// Consecutive probe failures before the room is called unreachable. An endpoint
  /// that is down forever is polled forever otherwise, which is how a transient API
  /// problem becomes a silently dead watcher.
  int maxProbeFailures;

  /// Consecutive failed captures before the task fails. Distinct from
  /// [maxProbeFailures] because a room that answers fine and never delivers media
  /// is a different problem from an API that is not answering.
  /// `0` never retries — the recorder settings' "自动重连" off is this.
  int maxCaptureFailures;

  /// How long a capture may go without any media time or bytes advancing before it
  /// is ended and joined. An HLS playlist can refresh forever with no new segment,
  /// and a connection kept alive by nothing never trips the transport's own timeout.
  Duration stallTimeout;

  /// A recording shorter than this is not worth a file: it is a blip, and the
  /// session is expected to be captured by the attempt that follows.
  Duration minUsefulRecording;

  /// Free space the session directory must have before another capture starts.
  /// `null` from the [RecordFiles.freeBytes] implementation means "unknown", which
  /// is not "zero": recording proceeds and lets the writer fail honestly.
  int diskFloorBytes;

  /// Whether segments found and joined at launch are announced. They are news about
  /// a recording the viewer thought was lost.
  bool notifyOnRecovered;

  /// Whether a merged file is given its display name. Off leaves the ASCII name,
  /// which is what a host that syncs files to a server with its own scheme wants.
  bool renameAfterMerge;

  /// Whether rooms that have never been seen live are checked again for their
  /// first broadcast. Off (the recorder settings' "开启开播检测" is off by
  /// default): a task waiting to start sleeps until the host asks again —
  /// re-watching the room or a launch that resumes waiting tasks. A session
  /// that was already live keeps being watched either way, because ending
  /// the recording on the room's close is correctness, not eagerness.
  bool enablePolling;

  /// Whether the wait between first-broadcast checks doubles after each offline
  /// answer, capped at [maxPollInterval] (the "递增检测间隔" of the settings).
  bool pollBackoff;

  /// Ceiling of the backed-off [pollInterval] while [pollBackoff] is on.
  Duration maxPollInterval;

  /// Whether an almost-empty end counts as a session that is still starting.
  bool isShortRecording(Duration mediaTime) => mediaTime < minUsefulRecording;

  /// Whether the room's state is one a capture should be running for.
  static bool shouldCapture(RoomState state) => state == RoomState.live;
}
