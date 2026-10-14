# live_record_core

The recording ledger: what a room is doing, where its files are, what those files
still owe, and how a launch finishes the work a crash left behind.

## Purpose

A recorder that keeps its whole state in memory cannot survive the two things that
actually happen to live recordings — the app is closed while segments are still
unjoined, and the network is pulled while the room still says live. This package
keeps the ledger instead of the memory: every task is a record with an id, a
directory, a list of attempts that have not been joined, and a display name that may
not have been applied yet. A launch reads that ledger first and finishes it, so a
recording is not lost because the process that was writing it is.

It also separates the questions that a single status string conflates. "The room is
not up" and "the broadcast ended" look identical to a status endpoint and are nothing
alike to a viewer — one has nothing to show and the other has a file to deliver.

## Responsibilities

- **Four state axes.** `ProbeOutcome` is what the platform answered. `RoomState` is
  what this package concluded (`waiting` versus `ended`, derived from whether this
  session was ever seen live). `RecordStatus` is where the task is in the queue.
  `ArtifactStage` is what the files still owe. Each answers one question, and only
  the last is the basis for recovery.
- **Capture-safe naming, three layers.** `RecordNaming` gives every task a random
  ASCII id (`rec_…`) used as FFmpeg's file prefix, inside
  `<root>/<platform>/<anchor>/<YYYY-MM-DD>` where the anchor component is pinyin or
  the room id. The Chinese name — `主播8891_2026-10-14-2240_今晚打老虎.mp4` — is built
  by `RecordPaths.displayNameFor` and applied only after the join, by
  `RecordFiles.rename`. The split exists because a Chinese path is where FFmpeg's own
  output handling fails first, while the rename is done by code with no such limit. A
  rename that fails leaves the ASCII file usable and records the intent, so the next
  launch tries again; it is never reported as a lost recording.
- **The join, and what refuses it.** A finished attempt is a `PendingAttempt`
  (directory, prefix, segments, bytes, media time) persisted the moment it ends.
  `RecordOrchestrator._finish` joins the list, and refuses to join across an attempt
  that reported damaged packets — those segments stay as they are, because rewriting
  them can lose the whole file to save one minute.
- **The queue and the waits.** `maxConcurrent` bounds how many rooms capture at once
  (the rest are `queued`); polling is jittered so N rooms do not reach the platform's
  endpoint in the same second; a recording that ended almost immediately is
  re-checked on `recheckInterval` rather than after the full poll, because a
  streamer restarting an encoder looks exactly like one who stopped.
- **The stall case.** While a capture runs the room is not polled — the capture is
  the better instrument, and two timers watching one fact disagree. A stream that
  keeps delivering bytes with no media in them is caught by `stallTimeout`, which
  closes the attempt and asks the room again, and the real end of a broadcast arrives
  as `RecordCapture.ended`.

## What this package does not do

It runs no FFmpeg, opens no socket, asks no platform API and draws no notification.
Those are `RecordServices`, implemented by the app shell:

| member | wired to |
| --- | --- |
| `probe` | the site's own room-status endpoint (`live_sites`) |
| `openCapture`, `files.merge` | `media_core_recording_ffmpeg` (`FfmpegRecordingBackend`, `FfmpegRecordingRemuxer`) |
| `acquireGuard` | `media_core_native` — `BackgroundExecution.acquire(notification:, wakeLock: true)`, the Android foreground service and partial wake lock that keep capturing after the screen goes off |
| `notify` | `media_core_notify`, or the host's own tray |
| `files.exists`, `files.rename`, `files.freeBytes` | `dart:io` |

That split is the rule in `docs/packages-migration.md` — a domain package imports no
engine — and it is what lets a host replace any one of them, including this
package's idea of how a room is probed.

## Using it

```dart
final orchestrator = RecordOrchestrator(
  services: AppRecordServices(),          // the five members above
  store: RecordJsonStore(hiveSlots),      // one JSON document per task
  naming: RecordNaming(rootDirectory: await recordingsPath()),
);

final left = await orchestrator.restore();   // joins and names what a crash left
if (left.joined > 0) {
  // the viewer is told about each recovered file
}

await orchestrator.watch(
  const RecordTarget(platform: 'douyin', roomId: '8891', anchorName: '主播8891'),
);
```

`watch` returns after the first check: a room that is not up yet is a normal answer,
not a failure. `stopWatching` closes the capture and joins what it wrote — stopping
is not discarding.
