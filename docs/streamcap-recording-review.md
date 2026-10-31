# StreamCap recording reference review

Reviewed on 2026-10-31 against the local checkout at
`C:\Users\m1779\Downloads\StreamCap` (StreamCap 1.x, Python/Flet/FFmpeg).

Sources read:

- `README.md`, `config/default_settings.json`
- `app/core/recording/stream_manager.py`, `record_manager.py`
- `app/core/media/ffmpeg_builders/base.py`, `direct_downloader.py`
- `app/models/recording/*`, `app/ui/views/recordings_view.py`,
  `app/ui/views/settings_view.py`

The review asks one question per layer: **what does StreamCap do that this
app's recorder does not, and which of those decisions should be carried
over?** The answer is in the parity table and the "not ported" list below.

## 1. Architecture map

| Concern | StreamCap | Pure Live |
|---|---|---|
| Live check | `RecordingManager.check_all_live_status` every `loop_time_seconds` (180 s default), one semaphore per platform (`platform_max_concurrent_requests`, 3) | `RecordingLiveMonitor` ticks every 5–15 s; each waiting task checks on its own interval with optional exponential backoff |
| Stream resolution | `LiveStreamRecorder.fetch_stream` via StreamGet platform handlers | `resolveRecordableStream` over the live_sites room/quality/line capabilities |
| Capture | `LiveStreamRecorder.start_ffmpeg` spawning FFmpeg per task | `FfmpegRecordingBackend` from `media_core_recording_ffmpeg`, segmented capture with a CSV journal and a JSON manifest |
| Retry | App-level restart on FFmpeg exit; `recheck_live_status` after a long run | Backend re-opens the source `restartLimit` times with backoff; `urlRefresher` re-mints signed URLs |
| Post-processing | TS → MP4 stream-copy remux (`convert_to_mp4`) | **added in this pass**: segment join into one MP4 after the take |
| Task state | `Recording` model with monitor/live/recording flags, persisted JSON list | `RecordingTask` with `waiting / recording / stopped / failed`, persisted through `live_storage` |
| Notification | Desktop notification + 8 webhook channels | `media_core_notify` job reporting; live alerts already exist |

## 2. Capture command knowledge

StreamCap's builder (`ffmpeg_builders/base.py`) is worth reading as a list of
failures rather than flags. The useful decoded rules:

- **Stream discovery must be patient.** `-analyzeduration 20 s`,
  `-probesize 10 MB` (overseas: 40 s / 20 MB), and `-bufsize 8000k`
  (overseas 15 MB) before the input.
- **Live inputs must reconnect inside FFmpeg**:
  `-reconnect_streamed`, `-reconnect_at_eof`, `-reconnect_delay_max 60`.
- **Damage should be discarded, not fatal**: `-fflags +discardcorrupt+igndts`,
  `-correct_ts_overflow 1`, `-avoid_negative_ts 1`, `-flush_packets 1`.
- **Muxing must tolerate bursts**: `-max_muxing_queue_size 1024` (overseas
  2048), `-thread_queue_size 1024`.
- **HLS extension mismatch is a platform fact**: CHZZK needs
  `-extension_picky 0` on FFmpeg 8.
- **Stream copy, not re-encode**, unless a custom bitrate was requested.
- **FLV is preferred for Douyin/TikTok, HLS elsewhere**, and an H.265 FLV
  input must fall back to HLS or TS.
- **Force HTTPS when the platform tolerates it**, with a small HTTP-only
  list (Shopee, Migu).

`media_core_recording_ffmpeg` carries all of this after the parity pass:
reconnect for HTTP, `+genpts+discardcorrupt`, discontinuity thresholds, packet
flushing, positive DTS, stream copy, per-container segment options, a
twenty-second / ten-megabyte analysis window, and an `extensionPicky` switch
the app turns off for CHZZK.

## 3. Settings and defaults parity

`config/default_settings.json` is the source for StreamCap's defaults.

| Concern | StreamCap key / default | Pure Live before | This pass |
|---|---|---|---|
| Segment length | `video_segment_time` / 1800 s | 300 s | 1800 s default |
| Input queue | builder `thread_queue_size` / 1024 | 2048 | 1024 default |
| Free-space guard | `recording_space_threshold` / 2.0 GB | 200 MB | 2048 MB default |
| Concurrent takes | `platform_max_concurrent_requests` / 3 | 3 | unchanged |
| Live-check interval | `loop_time_seconds` / 180 s | 30 s + per-task backoff | unchanged (more responsive, already configurable) |
| Schedule | `scheduled_recording` + `monitor_hours`, one window per task | waiting always | optional local weekday/time window on top of waiting |
| Record quality | `record_quality` / `OD` | 原画 | unchanged |
| Container | `video_format` TS, `convert_to_mp4` true | TS segments, no join | TS segments + join to MP4, on by default |
| Original files | `delete_original` false → move to `original/` | segments left in place | joined MP4 + `original/` subfolder, or delete |
| Naming | anchor/title/time, emoji removal, 30-char title cap | `{date}_{title}` template + timestamp | unchanged (template already covers the fields) |
| Folder layout | `folder_name_platform/author/time/title` | one flat take folder | not ported (see below) |
| Disk guard scope | checked before each start *and* periodically | before each start (backend) | unchanged |
| Progress | speed, cumulative duration, status | bytes only | media duration + bytes/s on the card |
| Post-record transcode | optional `video_bitrate` re-encode | none | optional H.264 pass with a bitrate choice |
| Network proxy | `-http_proxy` for listed platforms | none | follows the app proxy (HTTP endpoints only) |
| TLS trust | host CA bundle / platform default | OpenSSL build path (broken on Android) | bundled Mozilla CA bundle + optional verification switch |
| Filenames | cleaned title/anchor, Unicode kept | Unicode kept, passed to FFmpeg | ASCII temp capture, Dart rename to the template name |
| Notifications | desktop + webhooks | system job reports | unchanged |

## 4. What this pass changed

1. **Post-record join (`recorder_engine.dart`).** A take that ends
   successfully runs `FfmpegRecordingBackend.combineLastRecording()` (stream
   copy to `*.combined.mp4`, `+faststart`). The task is saved first, then the
   join runs behind it and replaces the folder path with the MP4 path. A
   failed join leaves the segments exactly as captured.
2. **Original segments stay recoverable.** With the new
   `recorder.combineDeleteOriginals` off (default), segments, journal and
   manifest move into `original/` beside the MP4. On, segments and the concat
   instruction are deleted; the journal and manifest stay as provenance.
3. **Cache safety during a join.** Joining takes are marked active, so the
   cache cap and "clear cache" cannot delete segments while FFmpeg reads them.
   Shutdown waits for an in-flight join instead of truncating it.
4. **Duration and speed.** `RecordingTask.durationMs` stores media time
   (stream clock, not wall clock); the engine writes it with every progress
   tick and on stop. Cards show `mm:ss` (or `h:mm:ss`) plus the average write
   rate, and the menu offers "Play recording" once the joined file exists.
5. **Settings shape.** The join switch and its "delete segments" companion
   sit in the 文件 page. The companion follows the switch's visibility, like
   the page's other dependent value rows (size cap, concurrency, disk guard,
   live-check interval, cache cap) — the page's established rule, kept as the
   user chose it on 2026-10-27. Both new keys are in the backup manifest and
   the settings search.
6. **Defaults aligned with the reference**: segment 30 min, queue 1024, disk
   guard 2 GB (see the table above).
7. **Post-record transcode.** After the join, an optional second pass
   re-encodes the MP4 with `libx264 -preset veryfast -b:v`, audio copied. It is
   off by default; the bitrate is a choice of 1.5–8 Mbps (plus any restored
   value). The transcode writes a `*.partial.mp4` and renames it only after a
   complete encode. The new `FfmpegRecordingTranscoder` lives in
   `media_core_recording_ffmpeg`.
8. **Proxy.** The recording now follows the app proxy: the effective
   `HttpProxyRoute` becomes `http://host:port` and is passed as
   `-http_proxy` to FFmpeg's HTTP input, for both HTTP and HTTPS sources. A
   PAC script or a SOCKS-only proxy still resolves to direct, because FFmpeg's
   HTTP protocol cannot express them.
9. **TLS trust.** FFmpeg's prebuilt OpenSSL keeps a build-machine CA path that
   does not exist on a phone, so public HTTPS chains failed verification on
   Android. The app now ships the Mozilla CA bundle as
   `assets/certs/cacert.pem`, copies it to its persistent data area, and passes
   it as `-ca_file`. A new "verify HTTPS certificates" switch (default on)
   can be turned off for a self-signed or TLS-intercepting proxy, with the
   security warning in its description. The same `FfmpegRecordConfig` fields
   (`caFile`, `tlsVerify`, `proxy`) are in `media_core`.
10. **Unicode titles.** The capture now runs under an ASCII temporary name
    (`rec_yyyyMMdd_HHmmss_SSS`), so a Chinese/emoji title never reaches FFmpeg's
    native path handling — a prefix repeats in every segment, the journal and
    the concat list, so one FFmpeg quirk would take the whole take with it.
    (The *folder* around it is not a risk; see the non-ASCII path finding in
    section 5.) After the join/transcode, Dart renames the take folder, the
    final MP4 and the chat sidecars to the rendered template name. A folder/file
    rename that is locked leaves the temporary name instead of losing the
    recording.
11. **FFmpeg initialization.** The backend, remuxer and transcoder now warm
    FFmpegKit before their first process. Without it a host that never called
    `backend.initialize()` threw "not initialized" on the first recording or
    join; the warm-up is idempotent, so an explicit call still costs nothing.
12. **Hybrid schedule.** The waiting model is the base; a task can add an
    optional local-time window (weekdays, start/end, overnight, stop-at-end).
    Outside the window the monitor makes no platform request; a stopped
    scheduled task re-arms at the next window and does not restart inside the
    window it already recorded. Boot recovery and the "record whenever live"
    default are unchanged. `RecordingTask` carries the fields; the monitor
    gates checks, re-arms at a window opening, and stops a take only when
    `stopAtWindowEnd` is on.
13. **Changing the save folder mid-recording.** A take resolves its root when
    it starts and keeps it through capture, join, transcode, rename and chat.
    Moving the recordings folder only affects later takes; both folder pickers
    confirm first when a capture is running, and the cache card says its
    figures and trimming cover the current folder only while an old-root take
    is finishing. The app never reaches into the folder the viewer left to
    enforce the new cache cap.
14. **Post-processing status, failure warnings and a cross-window lock.**
    `RecordingTask.postProcessing` shows a card as "processing" until the join,
    transcode and rename finish; `warning` carries a stable code for a failed
    join/transcode, a generic finalize failure or stale work, and the card
    renders it in the warning tone. The take's folder holds
    `.pure_live_finalizing.lock` while the work runs and stale recovery probes
    that lock at startup, so a crashed status does not stick forever while a
    live join in another window is left alone. `_hasForeignRecording` now
    treats a processing task as foreign, so another window's cache trim/clear
    stands down.
15. **Disk patrol, post-processing progress and cancellation.** A running take
    probes its volume every minute once a disk watermark is configured; below
    it the engine stops the take with the `disk-low` warning and skips the
    join/transcode so it does not write a second copy onto the full disk. The
    finalize step also probes before starting. The card shows a determinate
    progress bar during a transcode (processed media time / input duration) and
    an indeterminate one during a join (output bytes / segment bytes); the
    task menu offers "cancel processing", which cancels the FFmpeg execution
    and finishes with the `canceled` warning while keeping what was produced.
16. **Log privacy and cache responsiveness.** FFmpeg debug argv now redacts
    signed URL queries and credentials, and replaces the header block with
    `<redacted headers>`; the error log and URL-refresh failure use the same
    redaction. Recording cache size, trim and clear walks are asynchronous
    (`Directory.list`/`File.length`/`stat`), so a folder with thousands of
    segments no longer blocks the UI isolate for the whole walk.
17. **Start a waiting task now.** The task menu offers "start now" for a
    waiting/stopped task, resolving the current line exactly as the monitor
    does and starting the engine regardless of the schedule window. It reports
    offline, no-line, timeout and engine failures as separate messages.
18. **The join writes a partial file and renames it.** `FfmpegRecordingRemuxer`
    now targets `<prefix>.combined.partial.mp4`, deletes a stale partial, and
    renames only after FFmpeg exits successfully. An interrupted join can no
    longer leave a file a later run would accept as complete.
19. **Window-boundary timer.** Instead of a minute-by-minute poll for a
    schedule that may be days away, the monitor computes the next window start
    and sleeps until it (capped at an hour). A task waiting inside its window
    still uses the live-check cadence, and a recording with stop-at-end keeps
    the periodic clock for an on-time stop.
20. **The tasks are backed up.** `BackupDocument` grew a `recordings` section
    (task id → the task's own storage JSON) beside the follows, history, areas
    and settings, so a file or a WebDAV copy carries the recorder's setup —
    including each task's window — to another device. A restore reads the
    entries as *idle* tasks: a take that was recording becomes a waiting one,
    and a half-finished post-processing flag, its progress and the warning
    codes are dropped, because no session runs behind a restored entry. Two
    refusals happen before the first write, so a refused restore is whole: the
    document's task section is not restored while this device still owns a
    take (`recording` or `postProcessing` in the shared store — another
    window included), and a document that carries nothing at all is rejected
    instead of emptying the stores. Sections stay backward-compatible: a file
    written before `recordings` existed simply does not carry it, and the
    local tasks are then left alone.

21. **A take the app never finished can be finished by hand.** The
    post-recording steps no longer live on the capture session: `_endAs` and
    `RecorderEngine.retryFinalize` both build the same `_FinalizeTarget` (task
    id, session start, take folder, capture prefix, wanted name, a join closure
    and a close closure), so a re-run joins, re-encodes, archives and renames
    exactly as a normal stop would — with the same 处理中 status, progress bar,
    cancel item and finalize lock. The task is read back from its own folder:
    `<prefix>.clock-v1.json` names the journals and therefore the *closed*
    segments, and when no manifest is left but a `*.combined.mp4` /
    `*.transcoded.mp4` is, that file is taken as the join's result and the
    remaining steps (name, archive, status) still complete. The task menu's
    「重新合并」 is offered whenever a task names a take and nothing is running;
    refusals name their cause (busy, folder gone, nothing joinable). Two
    details make a re-run safe: the take name is rendered from the task's own
    start time rather than the retry's clock, and a folder that already carries
    that name is not treated as a collision, so a retry cannot mint a `_2` twin.
    A retry always joins, whatever the standing 合并 switch says; the transcode,
    delete-originals and disk-watermark rules keep applying.

22. **Whole-list actions.** The recorder header carries a batch menu beside the
    title: stop every capture (each take ends as a user stop, so its segments
    stay and its join runs as usual; a session another window owns is skipped
    rather than faked) and clear the settled rows (stopped/failed and not
    processing — the cards leave, the files stay where they are). Both confirm
    with the count they will act on, both report what actually happened, and an
    item only appears when it has something to act on. Bulk *starting* is
    deliberately missing: the live check already begins a waiting room when it
    goes on air, and forcing an offline one is what each card's "start now" is
    for.

23. **Other folders' recordings can be brought home.** A viewer who moved the
    recording folder kept every earlier take where it was, and the cache
    figures could only ever cover the current folder. `strandedTakes()` reads
    that set out of the task store — a settled row whose path is not under the
    current root — and `moveStrandedTakes` renames the take in place on one
    volume, or copies it across, measures the copy against the source (per file
    and in total), re-points the task row **before** deleting the source, and
    discards a half or mismatched copy rather than touching the original. Takes
    being captured or finished are never in the list, whoever owns them. The
    cache section shows the count, runs with live per-take progress and a real
    cancel, and reports moved/failed. The copy, rename, re-point and cancel
    paths were exercised by a standalone Dart probe against the same code
    (same-volume rename, cross-folder copy with byte comparison, mid-copy
    cancel leaving the source intact, and a name collision landing on `_2`).
24. **A CA bundle of the viewer's own.** Next to the verification switch, the
    capture settings can name a PEM bundle (`recorder.customCa`); its bytes are
    staged into the app's certificate folder and passed as `-ca_file` in place
    of the bundled Mozilla store. That is the way to trust a corporate root or a
    self-signed chain *without* turning verification off — the switch stays on
    and the protection it gives is kept. Staging the copy rather than naming the
    picked path is what makes it survive a viewer tidying the folder the file
    came from (and it is what lets Android work at all, where a picked document
    is not a path FFmpeg can open). A named file that cannot be read, is empty,
    or holds no `-----BEGIN CERTIFICATE-----` fails the start with a message
    pointing at the row; it never quietly falls back to the bundled store, and
    the row itself says when its file has gone missing.
25. **The merge logic moved to where it can be tested.** `takeDirectory` is a
    string getter on the task and `strandedTasksOf(tasks, rootPath)` a function
    on the task list, both in the data layer with no `dart:io`: the engine keeps
    the copying, the page keeps the counting, and neither has to be launched to
    be checked. `test/live/recording_paths_test.dart` covers a file path, a
    directory path, POSIX and Windows separators, a path with no extension, the
    recording/processing exclusions, a root with a trailing separator and a
    foreign-style path that a POSIX root cannot contain — 3 tests, and the
    schedule tests still pass 7. The rule was later narrowed: “the tail carries
    a dot” misreads a take folder named after a room like “3.5 万粉纪念”, so only
    a `.mp4` tail is a file and everything else is the folder (REC-57).

26. **A finished recording's notification names the room.** The notification
    itself was already wired — `enableUserNotifications` installs
    `media_core_notify`'s job reporter, and the backend reports the start and
    the outcome (`NotifyOn.results`, so only results are shown). What it said was
    the capture prefix: an ASCII filesystem stem like `rec_20261031_120000_000`,
    which is the one part of the line a viewer cannot place. `FfmpegRecordConfig`
    now carries an optional `jobLabel` (the host's human name, trimmed; blank
    falls back to the prefix), both report sites use it, and the app passes the
    room title with `platform:roomId` as the fallback. File naming and the disk
    layout are untouched. A tap now lands in the recorder centre: the payload is
    the take's directory, which the finalize rename moves, so there is nothing
    stable to open — the notification handler routes a non-live tap to
    `recordingTapHandler`, which the app shell registers as a jump to the
    recorder's own route. A cold-start tap, before that handler exists, brings
    the app forward only, the same limit a live alert has.

27. **Gift messages can join the recorded danmaku.** The reference keeps an
    independent `record_danmaku_gifts` switch, and the recorder now does too:
    `recordDanmakuGifts` (`recorder.chatGifts`, off by default, so the previous
    behaviour is what you get until you ask) lets gift lines into the sidecar
    beside the chat. The rule lives in one pure function, `recordableDanmaku`:
    the chat is always kept, a gift only when the switch is on, and everything
    else on the stream — audience counts, notices, entries, retractions — never,
    because a danmaku file is something a viewer reads back and room state is
    not part of what was said. The engine reads the two switches once per
    message; the writer is unchanged, since a gift arrives as text like any
    other line, and all five formats therefore carry it for free. A test walks
    the whole `LiveMessageType` enum so a new kind of message is a deliberate
    decision rather than a stray line in someone's file.

28. **A "recording" row this window does not write now says so.** The boot
    recovery turned out not to be silent: `_resumeInterrupted`, gated on the
    launch switch, returns interrupted rows to waiting and — with the live check
    off — still forces one round, which is the reference's behaviour. The silent
    case is the switch being *off* (its default): the row keeps "recording", this
    window's engine holds no session for it, so no stop action appears and
    "start now" is refused by the state itself — delete is all that is left. A
    clone window's genuinely live recording looks identical from here, and the
    store cannot tell them apart, so the card does not guess or write: it adds a
    line that is true either way ("this window is not writing it; if another
    window is recording, that one owns it — otherwise the last process was
    interrupted…"), and the launch switch's description now names both the forced
    check and the off-state consequence.

29. **The move's file rules are a module, not an engine detail.** Measuring a
    folder, copying one take into another home and proving the copy, and reading
    a task's path after the move now live in `recording_take_move.dart`, with the
    engine keeping only the decisions around them. That is what makes the
    riskiest rule testable: the copy is judged by per-file lengths **and** by the
    two totals, and a test fills the destination with a stranger's file to prove
    the total is what catches it — a file-by-file check alone would have deleted
    the source. The other tests cover the nested shape (Chinese names included),
    a cancelled copy leaving the source whole, and the four path shapes a row can
    carry.

30. **The task store's write guards are pinned.** The repository's rules — a new
    take keeps its schedule and drops the last take's facts, post-processing only
    begins on an ended row of the expected session, progress and the final path
    are refused for a row a newer take already replaced, finishing clears the
    flag and records the warning, a progress tick never moves the state — are
    exactly the class of bug the double-branch finalize once had. They are now
    six tests over an in-memory `JsonStore` (the interface is abstract, so no
    database is needed), with non-default schedule values so an assertion cannot
    pass by matching a default.

31. **The backup document and the restore guard are pinned.** A restore clears
    stores, so its rules are data-loss boundaries, and they had no test at all.
    Ten now cover the codec (a round trip through the wire form, `{}` and
    untagged rubbish read as "not a backup", a tagged-but-empty document as a
    real empty one, wrong-shaped entries dropped while an unknown section is not
    claimed, a follows-only document carrying nothing else, the stamped export
    name) and the repository over in-memory stores: a carried section replaces
    its store while an absent one is left alone, follows-only touches only the two
    follows stores, an empty document is refused before any write, and a live or
    still-finishing take makes the restore refuse with every store exactly as it
    was — the "all or nothing" rule as an executable assertion. The restored tasks
    are checked to come back idle, with an entry that names no room dropped.

32. **A settings reset no longer contradicts the stored CA choice.** `reset()`
    replaced the whole state with the defaults, which put `customCaPath` back to
    "bundled store" in memory while — by design — not writing that preference.
    The page then said "bundled" while the pref still held the viewer's file and
    the next launch silently brought it back. The defaults copy now carries the
    current path over (`d.copyWith(customCaPath: state.customCaPath)`), so every
    tunable returns and the one picked file stays; a test pins exactly that. It
    is analysed but not yet executed: `flutter test` has to relink
    `media_kit_event_loop.dll` and another live process holds the file
    (`LNK1104`), which is not something to force from here; `flutter build
    bundle` does not relink it and is green with the fix.

33. **Two windows cannot capture one room.** The engine's session table is
    per process, so a task started in one window was invisible to the other. The
    claim file (`recording_claim.dart`) is taken before the task's stub is
    written and released by the end path, by a failed start, and when the stub
    itself cannot be stored; the operating system drops it with the process, so
    a crash never leaves a task looking busy. A claim that cannot be taken —
    held elsewhere, or a folder that will not accept the file — refuses the
    recording, which is the safe direction: two takes on one room would write the
    same row twice and produce two directories nobody asked for. The mechanism
    was run on this machine through a Flutter-free script (second acquire fails,
    another task succeeds, release frees it again); the wiring is covered by
    analysis and the bundle build, with its unit test waiting for a test
    environment that is not currently blocked by a locked native-asset DLL.

## 5. Deliberately not ported

## 5. Deliberately not ported

- **Webhook push (DingTalk/WeChat/Feishu/Bark/ntfy/Telegram/email/ServerChan).**
  A separate notification subsystem with credentials and retry policy; the
  app already delivers system notifications, and adding eight channels is not
  a recorder setting.
- **Custom post-record script.** Running user-provided commands from a media
  app is a security and packaging decision (and impossible on Android/iOS);
  the user explicitly declined it.
- **Direct FLV downloader.** FFmpeg already writes FLV/TS; a second download
  path duplicates the failure handling the backend owns and loses crash
  recovery.
- **Force-HTTPS and FLV/HLS preference.** `live_sites` resolves the line and
  headers the platform accepts; the recorder uses that line.
- **Folder layout switches (platform/author/date/title).** The naming
  template plus one folder per take already keeps files identifiable; adding
  four layout switches would duplicate the template's job.

### Android certificate finding

The prebuilt `libffmpegkit.so` (the AAR the build hook stages) contains the
compile-time CA path `/prebuilt/android-aarch64/libraries/ssl/cert.pem`. That
path is a build-machine directory, not something that exists on an Android
device, so OpenSSL has no trust store and a public HTTPS chain fails with
"unable to get local issuer certificate" even though the phone's own browser
trusts it. The fix is not to disable verification: the app now supplies the
Mozilla CA bundle with `-ca_file`. Inspect the library with a byte-string scan
if this needs re-checking after a plugin upgrade.

### Non-ASCII (Chinese) path finding — a parent folder is safe

The recorder names each take in ASCII, which raised the follow-up question:
what if the *folder the viewer chose* is Chinese (`D:\录播`)? That is the
common case for this app's users, so it was settled with evidence rather than
assumption.

Upstream FFmpeg converts the filename itself. `libavformat/file.c`'s
`file_open` calls `avpriv_open`, and `libavutil/file_open.c` defines
`win32_open` for **every** `_WIN32` build (MinGW included, there is no
`!__MINGW32__` guard): `get_extended_win32_path()` →
`MultiByteToWideChar(CP_UTF8, …)` → `_wsopen` with a `\\?\` extended prefix,
falling back to the code-page `_sopen` only when the wide call fails *and* the
file is not being created. So FFmpeg expects UTF-8 bytes and opens Unicode
paths through the wide API regardless of the system ANSI code page.

The Flutter side delivers exactly that: `ffmpeg_kit_extended_flutter` 1.0.0
marshals every argument with `toNativeUtf8` before the native call (verified at
each call site in `platform/native/backend_native.dart`), and the staged
Windows binary (`libffmpegkit.dll`, `Lavf 63.1.102`) imports
`MultiByteToWideChar`/`_wfopen`/`CreateFileW`. A CLI control run — segments with
the recorder's own `-f segment` pattern, the remuxer's
`-f concat -safe 0 -i list.txt -c copy -movflags +faststart` join, and the
transcoder's argument shape — wrote and read through
`…\Temp\录播中文路径测试\…` and through a traditional/emoji folder name with
exit 0 on both local builds (FFmpeg 8.1.1 and 9.0.1).

Two honest limits: the control machine runs ACP 65001 (UTF-8 system code page),
so the CLI run alone could not tell the wide path from a lucky code page — the
source guard above is what makes the conclusion safe on an ACP 936 or 1252
machine; and FFmpegKit's own Windows toolchain was not rebuilt here, only its
staged binary inspected. Android and Linux need none of this: paths are UTF-8
bytes at the syscall level.

The consequence for the design: the ASCII take name is **defence in depth** for
the segment prefix (a prefix repeats in every segment, the journal and the
concat list, and a broken prefix loses the whole take), not a workaround for a
folder that FFmpeg cannot write to. A Chinese recording folder is fine as it
stands, so nothing warns about it.

## 6. Remaining gaps and risks

- **Resume a pending join on the next start.** A take saved before a crash is
  stored as `stopped` with the temporary or final directory path, and the
  monitor does not re-run its finish by itself; the viewer starts it from the
  task menu (item 21). The segments and manifest are intact either way.
- **A switched-off live check strands a schedule, silently.** While
  `pollingEnabled` is off the monitor starts no waiting room and re-arms no
  scheduled one — only a running take's window-end stop still happens, because
  `_stopExpired` runs ahead of that guard. The recorder's banner now counts
  those rows with the waiting ones (`RecordingTask.needsLiveCheck`): a stopped
  task waiting for its next window is exactly as stranded as a room waiting to
  go live, and it said nothing.
- **Self-signed / intercepted certificates** are covered by the custom CA bundle
  (item 24) rather than by turning verification off; the switch stays the last
  resort for a chain whose bundle the viewer cannot export.
- **Proxy authentication and SOCKS/PAC.** Measured, not assumed — see
  `test/app/proxy_credentials_test.dart`, four loopback-proxy tests:
  `HttpClient.addProxyCredentials` **works and works eagerly**, putting
  `Proxy-Authorization: Basic …` on the first request (a proxy that challenges
  with 407 is satisfied by that first request, with no challenge round) and on
  the CONNECT of a tunnel, so HTTPS traffic can cross an authenticated proxy.
  The credential is bound to the host:port it was registered for — a second
  proxy on the same host and another port is offered nothing. Two traps:
  `HttpClient.authenticate`/`proxyAuthenticate` are declared and implemented
  nowhere (they throw `no such method`), and the route-string form
  `PROXY http://user:pass@host:port` mis-parses — the userinfo is cut at the
  last `@` and then the first colon, so the scheme lands inside the username and
  the proxy is handed `Basic` of `http://user:pass`; the schemeless
  `PROXY user:pass@host:port` is what that parser wants. FFmpeg's `-http_proxy`
  takes no credential at all (`-headers Proxy-Authorization` is the way), mpv
  reads `http-proxy=http://user:pass@host:port`, and SOCKS or a PAC script stays
  out of reach for both. What blocks a credentials *setting* is therefore not a
  missing capability but a cross-surface decision — where the password lives
  (the vault, as with a WebDAV account) and how all three consumers are given
  the same answer, so no request path is left honouring it silently.
  Earlier claims in this document, that neither stack could authenticate, were
  wrong twice over; this is the measured version. **Status after REC-47:** the
  credential is now a setting — username in `proxy.username`, password in the
  device vault — and it reaches all four consumers: Dio's transport, the
  process-wide HTTP override (which is what WebDAV and every third-party client
  go through), mpv's `http-proxy` as a userinfo URL, and the recorder as a
  `Proxy-Authorization` header on the source, since FFmpeg's `-http_proxy`
  cannot take one. What remains out of reach is SOCKS and a PAC script.
- **Schedules use local wall time only.** There is no per-task timezone, and a
  daylight-saving jump is not compensated; the monitor sleeps until the next
  window boundary (capped at an hour, so a clock change is re-read at least
  hourly). A schedule's last-session start is compared in local time, so a
  clock change can shift one window once.
- **Scheduled/notify-only workflows** remain unimplemented by design (see
  above).
- **A restored task keeps the source device's paths.** The backup stores the
  task's record, not its media: `filePath` arrives verbatim, so on another
  device it points at a folder that may not exist until the room is recorded
  there.

## 6a. Runtime acceptance

Everything that only a real machine can answer is written up as a checklist —
`docs/recording-runtime-qa.md`: 33 numbered cases across basic capture, danmaku
(chat and gifts), the recorder centre's batch actions and re-join, finalize
failures and cross-disk merge, notifications and launch recovery, proxy and
certificates, backup round trips, and multi-window. Each states the action and
the expected observation, and how to report a failure. Writing it surfaced one
**real gap**, now closed: `RecorderEngine.start` only checked its own process's
sessions, so two windows could start the same task at once (REC-56). A per-task
claim now sits beside the finalize lock — a `.claim` file under
`<data>/recording_claims`, locked for the process's lifetime, so a crash releases
it instead of leaving a stale marker; a second start answers `recording-busy`,
which the card names as "another window is recording this room".

## 7. Verification

- `dart run slang` regenerated the recorder namespace.
- `dart run slang` regenerated the backup namespace too: `summary` gained
  `{recordings}`, and `restoreRecordingsBusy` / `restoreEmptyDocument` cover
  the two refusals.
- `dart analyze lib` in `apps/pure_live` reports no issues.
- `dart analyze` in `media_core_recording_ffmpeg` reports no issues;
  `flutter test` in that package passes 132 tests (including proxy, CA,
  transcode, URL-redaction and analysis-window tests).
- `flutter build bundle` exits 0 and stages
  `assets/certs/cacert.pem`; the schedule unit tests pass 7/7.
- After the retry work: `dart analyze lib` 0 issues, `flutter build bundle`
  exit 0, schedule tests still 7/7. No real take was re-joined in this pass —
  the interrupted-join and interrupted-rename folders need a runtime check.
- After the batch actions and the path finding: `dart analyze lib` 0 issues,
  `dart run slang` regenerated (recorder +12 keys), `dart format` clean,
  `flutter build bundle` exit 0. The prefs gate reports no recorder entry
  (its 132 lines are other modules' existing debt) and the settings IA gate's
  7 failures are the concurrent session's known list. The path conclusion was
  reached by reading FFmpeg's source and the plugin's marshalling plus a local
  CLI control run; the app itself has not been asked to record into a Chinese
  folder on an ACP 936 machine.
- `flutter build windows --debug` is blocked by the running app holding
  `WebView2Loader.dll`; `--release` is blocked by the fjs cargokit linker
  temp-path failure (`C:\Users\m1779\AppData` resolution) that predates this
  change. Both failures are environmental, not Dart compilation.
- No runtime capture was performed in this pass; the join path needs a real
  live room to exercise FFmpeg's concat demuxer.
