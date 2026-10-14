# Changelog

All notable changes to `live_record_core` are documented in this file.

## Unreleased

### Added

- The task ledger: `RecordTask`, `RecordTarget` and `PendingAttempt`, with a JSON shape that is read tolerantly (an unknown stored enum name falls back instead of throwing) and that never stores a signed media address — the room page is fine to keep, the stream URL is a credential and expires.
- Four state axes instead of one status string: `ProbeOutcome`, `RoomState`, `RecordStatus`, `ArtifactStage`. `RoomState.ended` is derived from having once seen the room live, which is the only way to tell a broadcast that finished from one that has not started, and `sawLive` is persisted so a restart does not forget.
- `RecordNaming` / `RecordPaths`: random ASCII capture ids, `<root>/<platform>/<anchor>/<day>` session directories (pinyin or room id for the anchor component), and the Chinese display name applied after the join. `safePathComponent` drops dots from untrusted labels, so a title cannot become a traversal, a hidden entry or a trailing-dot name Windows refuses.
- `RecordOrchestrator`: `restore()` for the launch sweep (join what a crash left, publish a merged file that never got its name, keep the evidence when a join is refused, never delete a capture-named file because a rename failed), `watch()` for the poll-and-capture loop, `stopWatching()` and `finishNow()`.
- `RecordServices`, `RecordCapture`, `RecordFiles`, `RecordGuard` and `RecordNotice`: the seam the app shell implements over `media_core_recording_ffmpeg`, `media_core_native` and the site's own status endpoint. `RecordCapture.ended` is part of the contract because a capture, not a poll, is what notices a broadcast stop.
- `RecordJsonStore` over an injected `RecordSlotIo`, so the ledger needs no filesystem in tests and a host can keep it in Hive. One unreadable document costs only itself.
- `RecordPolicy`: concurrency limit, jittered polling, short re-check after an almost-start, probe/capture failure budgets, stall timeout, disk floor, and the switch that leaves the file under its capture name.
- 29 tests over the ledger and the driver: the never-live room that stays silent, a session from 开播 to a joined and renamed file, a dropped connection retried into one merge, a refused join and a damaged attempt that is never rewritten, recovery after a power cut, and a rename conflict retried on the next launch.
