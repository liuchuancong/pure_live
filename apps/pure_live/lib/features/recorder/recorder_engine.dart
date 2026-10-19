// The named `._` constructors cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:async';
import 'dart:io';

import 'package:live_record_core/live_record_core.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart' show KeyedBox;
import 'package:media_core/media_core.dart'
    show RecordingConfig, RecordingResult, RecordingSource, RecordingState, RecordingStatus;
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/features/recorder/record_chat_writer.dart';
import 'package:pure_live/features/recorder/recorder_preferences.dart';

/// The app shell's side of the `live_record_core` contracts.
///
/// The kernel owns the task ledger, the naming rules and the recovery sweep;
/// everything that touches the outside world is implemented here and handed
/// to it through [RecordServices]:
///
/// - **probe** asks the room's own site (`live_sites`) what it is doing and,
///   when it is on air, resolves one playable line for the capture;
/// - **capture** runs `media_core_recording_ffmpeg`'s
///   [FfmpegRecordingBackend] — segmented MPEG-TS plus a journal, one backend
///   per capture, its file prefix forced to the task's ASCII id so the
///   kernel's naming rule holds;
/// - **files** joins a finished capture's segments through the package's own
///   remuxer and applies the display rename afterwards;
/// - the guard stays null (the backend holds its own keep-alive lease) and
///   notifications are accepted and dropped (this build has no tray for them
///   yet).
///
/// Nothing here decides *when* to record — that is the orchestrator's.

/// The task ledger's slot bytes, over one keyed string box.
///
/// An absent or empty slot reads back as null: the store then skips the
/// document instead of decoding it, which is how a half-written record from
/// a power cut is survived.
final class BoxRecordSlots implements RecordSlotIo {
  /// Slots over [box].
  const new(this.box);

  /// The open box (one JSON document per task, keyed by task id).
  final KeyedBox<String, String> box;

  @override
  Future<String?> read(String key) async {
    try {
      final value = box.getOr(key, '');
      return value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) => box.put(key, value).run();

  @override
  Future<void> delete(String key) => box.delete(key).run();

  @override
  Future<List<String>> keys() async => box.keys.toList(growable: false);
}

/// One running capture: an [FfmpegRecordingBackend] behind the kernel's
/// [RecordCapture] contract.
final class BackendRecordCapture implements RecordCapture {
  BackendRecordCapture._(this._task, FfmpegRecordConfig config)
    : _backend = FfmpegRecordingBackend(
        // The prefix is the task's capture id — the kernel's naming rule is
        // that FFmpeg only ever opens ASCII paths it can reproduce, and a
        // timestamped prefix would scatter one task's attempts over several
        // names. With a fixed prefix the timestamp switch is moot, and the
        // per-recording subdirectory is off so the session directory the
        // ledger already knows is where the files land.
        config: config.copyWith(
          filePrefix: _task.taskId,
          includeTimestampPrefix: false,
          // Two quick re-opens with a short ceiling: a CDN rotation recovers
          // within seconds, and a broadcast that is truly over should be
          // noticed by the capture this fast, not by the room poll a minute
          // later.
          restartLimit: 2,
          restartBackoff: const Duration(seconds: 2),
          restartBackoffMax: const Duration(seconds: 15),
          // The backend's own verify already opened the first and last
          // segments once; asking FFprobe to do it again on the join's
          // output doubles the native calls for little extra honesty.
          verifyPlayability: false,
        ),
        outputDirectory: _task.paths.sessionDirectory,
        // The volume is asked before the first segment, so a full disk is a
        // refusal with a name rather than an exit code after the fact.
        diskSpace: FfmpegDiskSpace.probe,
      );

  /// Opens a capture of [streamUrl] into [task]'s session directory, under
  /// the task's own ASCII prefix.
  static Future<BackendRecordCapture> start({
    required RecordTask task,
    required String streamUrl,
    required FfmpegRecordConfig config,
  }) async {
    final capture = BackendRecordCapture._(task, config);
    await capture._start(streamUrl);
    return capture;
  }

  final RecordTask _task;
  final FfmpegRecordingBackend _backend;

  final Completer<void> _ended = Completer<void>();
  final StreamController<RecordProgress> _progressController = StreamController<RecordProgress>.broadcast();
  StreamSubscription<RecordingState>? _states;
  StreamSubscription<FfmpegJournalledSegment>? _segments;
  RecordProgress _progress = const RecordProgress(mediaTime: Duration.zero, bytes: 0, segments: 0);
  CaptureOutcome _outcome = const CaptureOutcome(
    directory: '',
    prefix: '',
    segments: 0,
    bytes: 0,
    mediaTime: Duration.zero,
  );
  bool _settled = false;

  @override
  Stream<RecordProgress> get onProgress => _progressController.stream;

  @override
  Future<void> get ended => _ended.future;

  @override
  CaptureOutcome get outcome => _outcome;

  Future<void> _start(String streamUrl) async {
    await _backend.initialize();
    _states = _backend.onStateChanged.listen(_onState);
    _segments = _backend.onSegmentClosed.listen((_) => _advance(segments: _progress.segments + 1));
    // The source is handed over without a title on purpose: a titled source
    // becomes the file prefix, and the prefix here is the task's capture id,
    // not the room title. The room id stays as the manifest's source label.
    await _backend.start(
      RecordingSource.network(streamUrl, id: _task.target.roomId),
      RecordingConfig(outputPath: _task.paths.sessionDirectory),
    );
  }

  void _onState(RecordingState state) {
    _advance(mediaTime: state.duration, bytes: state.bytesWritten);
    if (!_ended.isCompleted) {
      switch (state.status) {
        case RecordingStatus.completed || RecordingStatus.error || RecordingStatus.cancelled:
          _ended.complete();
        case RecordingStatus.idle || RecordingStatus.starting || RecordingStatus.recording || RecordingStatus.stopping:
          break;
      }
    }
  }

  void _advance({Duration? mediaTime, int? bytes, int? segments}) {
    _progress = RecordProgress(
      mediaTime: mediaTime ?? _progress.mediaTime,
      bytes: bytes ?? _progress.bytes,
      segments: segments ?? _progress.segments,
    );
    if (!_progressController.isClosed) {
      _progressController.add(_progress);
    }
  }

  @override
  Future<void> stop() async {
    if (_settled) {
      return;
    }
    _settled = true;

    final RecordingResult result;
    try {
      result = await _backend.stop();
    } on Object {
      _outcome = _emptyOutcome();
      await _close();
      return;
    }
    _outcome = _outcomeFrom(result);
    await _close();
  }

  @override
  Future<void> cancel() async {
    if (_settled) {
      return;
    }
    _settled = true;

    try {
      await _backend.cancel();
    } on Object {
      // A cancel that threw still ends the ownership: the caller asked for
      // the files to be discarded, and an outcome of nothing says that.
    }
    _outcome = _emptyOutcome();
    await _close();
  }

  CaptureOutcome _outcomeFrom(RecordingResult result) {
    final check = _backend.lastCheck;
    return CaptureOutcome(
      directory: _backend.activeDirectory ?? _task.paths.sessionDirectory,
      // The manifest's prefix is the sanitised form the files actually
      // carry; for a capture id it is the id itself.
      prefix: _backend.lastManifest?.prefix ?? _task.taskId,
      segments: check?.segments ?? 0,
      bytes: check?.bytesOnDisk ?? result.bytesWritten,
      mediaTime: result.duration,
      // The capture already discarded corrupt packets while running
      // (`+discardcorrupt`), so the segments that exist are kept as what was
      // captured and left undamaged: the merge may still run over them, and
      // a verdict short of complete is the task's failure reason instead.
      failure: result.error?.toString(),
    );
  }

  CaptureOutcome _emptyOutcome() => CaptureOutcome(
    directory: _backend.activeDirectory ?? _task.paths.sessionDirectory,
    prefix: _backend.lastManifest?.prefix ?? _task.taskId,
    segments: 0,
    bytes: 0,
    mediaTime: Duration.zero,
  );

  Future<void> _close() async {
    await _states?.cancel();
    await _segments?.cancel();
    _states = null;
    _segments = null;
    unawaited(_progressController.close());
  }
}

/// The kernel's file layer, over the recording package's remuxer and the
/// platform's own file operations.
///
/// [merge] joins each attempt through [FfmpegRecordingRemuxer] — the join the
/// package documents as the host's move — and, when a task carries several
/// attempts, first brings each attempt to one MPEG-TS stream (the container
/// the package keeps for joins without repacking) and then remuxes that
/// stream to its final MP4.
final class FfmpegRecordFiles implements RecordFiles {
  /// Creates the file layer.
  new({FfmpegRecordingRemuxer? remuxer}) : _remuxer = remuxer ?? FfmpegRecordingRemuxer();

  final FfmpegRecordingRemuxer _remuxer;

  @override
  Future<MergeOutcome> merge({required RecordTask task, required List<PendingAttempt> attempts}) async {
    if (attempts.isEmpty) {
      return MergeOutcome(path: task.paths.asciiMergedPath, bytes: 0, mediaTime: Duration.zero, failure: '没有可合并的分段');
    }

    try {
      if (attempts.length == 1) {
        return await _mergeSingle(attempts.single);
      }
      return await _mergeMany(task, attempts);
    } on Object catch (error) {
      return MergeOutcome(path: task.paths.asciiMergedPath, bytes: 0, mediaTime: Duration.zero, failure: '$error');
    }
  }

  Future<MergeOutcome> _mergeSingle(PendingAttempt attempt) async {
    final result = await _remuxer.run(manifest: _manifestFor(attempt), directory: attempt.directory);
    return _outcomeOf(result, fallbackMediaTime: attempt.mediaTime);
  }

  Future<MergeOutcome> _mergeMany(RecordTask task, List<PendingAttempt> attempts) async {
    final first = attempts.first;
    var mediaTime = Duration.zero;
    final parts = <String>[];

    for (final attempt in attempts) {
      final result = await _remuxer.run(
        manifest: _manifestFor(attempt),
        directory: attempt.directory,
        target: FfmpegRemuxTarget.mpegTs,
      );
      if (!result.success) {
        return _outcomeOf(result, fallbackMediaTime: attempt.mediaTime);
      }
      mediaTime += attempt.mediaTime;
      parts.add(p.basename(result.outputPath));
    }

    // The per-attempt streams are joined through the remuxer's own path: a
    // synthetic journal in the first attempt's directory names them, and the
    // remuxer reads that list exactly as it reads a capture's. Every attempt
    // of one task shares the session directory, so the relative names hold.
    final journalName = '${task.taskId}.merge.clock-v1.csv';
    final listFile = File(p.join(first.directory, journalName));
    try {
      // The journal's line shape is the capture's own: `file,'<name>'`, the
      // name resolved against the journal's directory.
      listFile.writeAsStringSync(parts.map((name) => "file,'$name'").join('\n'));
    } on Object catch (error) {
      return MergeOutcome(path: task.paths.asciiMergedPath, bytes: 0, mediaTime: mediaTime, failure: '$error');
    }

    final merged = await _remuxer.run(
      manifest: FfmpegRecordingManifest(
        prefix: '${task.taskId}.merge',
        container: FfmpegRecordContainer.mpegTs,
        segmentTime: 0,
        startedAt: task.startedAt ?? task.createdAt,
        sourceLabel: task.target.roomId,
        journals: [journalName],
        attempts: attempts.length + 1,
      ),
      directory: first.directory,
    );

    // The intermediate streams and the synthetic journal are rebuildable
    // from the segments, so they are not kept: one recording should not
    // leave two copies of every byte behind.
    for (final name in [...parts, journalName]) {
      try {
        final part = File(p.join(first.directory, name));
        if (part.existsSync()) {
          part.deleteSync();
        }
      } on Object {
        // A leftover stream is disk noise, not a failed merge.
      }
    }

    return _outcomeOf(merged, fallbackMediaTime: mediaTime);
  }

  /// The manifest a merge reads: the capture's own when it survived, a
  /// rebuilt one from the journals on disk when it did not.
  FfmpegRecordingManifest _manifestFor(PendingAttempt attempt) {
    final journals = _journalsFor(attempt);
    return FfmpegRecordingManifest(
      prefix: attempt.prefix,
      container: FfmpegRecordContainer.mpegTs,
      segmentTime: 0,
      startedAt: DateTime.now(),
      sourceLabel: '',
      journals: journals,
      attempts: journals.length,
    );
  }

  /// Every attempt journal the prefix owns, oldest first — the manifest's
  /// list when there is one, the directory's matching `clock-v1` files
  /// otherwise (attempt 0 keeps the plain name, a re-opened attempt adds
  /// `_r<N>`).
  List<String> _journalsFor(PendingAttempt attempt) {
    final manifest = FfmpegRecordingManifest.read(
      File(p.join(attempt.directory, recordingManifestName(attempt.prefix))),
    );
    if (manifest != null && manifest.journals.isNotEmpty) {
      return manifest.journals;
    }

    final directory = Directory(attempt.directory);
    if (!directory.existsSync()) {
      return const <String>[];
    }
    final pattern = RegExp('^${RegExp.escape(attempt.prefix)}(_r\\d+)?\\.clock-v1\\.csv\$');
    final names =
        directory.listSync().map((entry) => p.basename(entry.path)).where(pattern.hasMatch).toList(growable: false)
          ..sort((left, right) {
            int rank(String name) => name.endsWith('.clock-v1.csv') && !name.contains('_r') ? 0 : 1;
            final byRank = rank(left).compareTo(rank(right));
            if (byRank != 0) {
              return byRank;
            }
            return left.compareTo(right);
          });
    return names;
  }

  MergeOutcome _outcomeOf(FfmpegRemuxResult result, {required Duration fallbackMediaTime}) {
    if (!result.success) {
      return MergeOutcome(
        path: result.outputPath,
        bytes: result.bytesWritten,
        mediaTime: fallbackMediaTime,
        failure: result.error?.toString() ?? '合并失败',
      );
    }
    return MergeOutcome(
      path: result.outputPath,
      bytes: result.bytesWritten,
      mediaTime: result.duration == Duration.zero ? fallbackMediaTime : result.duration,
    );
  }

  @override
  Future<bool> exists(String path) async {
    try {
      return File(path).existsSync();
    } on Object {
      return false;
    }
  }

  @override
  Future<int?> freeBytes(String directory) {
    // The same best-effort probe the capture opens the volume with; a null
    // answer is read by the kernel as unknown, never as zero.
    return FfmpegDiskSpace.probe(directory);
  }

  @override
  Future<RenameOutcome> rename({required String from, required String to}) async {
    try {
      final source = File(from);
      if (!source.existsSync()) {
        return RenameOutcome(applied: false, path: from, failure: '源文件不存在');
      }
      final destination = File(to);
      if (destination.existsSync()) {
        // A second recording already carries the display name this one wants
        // (same anchor, same minute): the capture name stays, which is the
        // honest outcome of a name collision.
        return RenameOutcome(applied: false, path: from, failure: '目标文件名已存在');
      }
      await Directory(p.dirname(to)).create(recursive: true);
      final moved = await source.rename(to);
      return RenameOutcome(applied: true, path: moved.path);
    } on Object catch (error) {
      return RenameOutcome(applied: false, path: from, failure: '$error');
    }
  }
}

/// The kernel's outside world, wired to this app's site graph and the FFmpeg
/// recording backend.
final class AppRecordServices implements RecordServices {
  /// Services over [registry], reading the whole preference document through
  /// [settingsOf] at the moment each decision is made — a settings edit
  /// reaches the next capture without a restart. [onNotice] receives the
  /// kernel's composed lines (started, saved, recovered) as system
  /// notifications; null keeps the old answer of accepting and dropping them.
  new({required this.registry, required this.settingsOf, this.onNotice});

  /// The site graph the rooms are asked through.
  final LiveSiteRegistry registry;

  /// The recorder's stored answers, read per decision.
  final RecorderPreferences Function() settingsOf;

  /// The notification sink: title line and body, fired and forgotten.
  final Future<void> Function(String title, String body)? onNotice;

  final FfmpegRecordFiles _files = FfmpegRecordFiles();

  @override
  RecordFiles get files => _files;

  @override
  Future<RoomProbe> probe(RecordTarget target) async {
    final site = registry.getById(target.platform);
    final rooms = site?.capability<LiveRoomProvider>();
    if (rooms == null) {
      return RoomProbe(outcome: ProbeOutcome.unavailable, detail: '平台 $target.platform 不支持查询房间');
    }

    final room = await rooms.getRoom(target.roomId).then((value) => value.fold((error) => null, (value) => value));
    final title = room?.content.title;
    final anchor = room?.anchor?.name;

    if (room == null) {
      return RoomProbe(outcome: ProbeOutcome.unavailable, roomTitle: title, anchorName: anchor, detail: '房间不存在或已不可访问');
    }

    if (!room.broadcast.isLiveNow) {
      // A banned room is gone rather than merely quiet; the kernel stops a
      // task whose room is unavailable instead of waiting it out.
      final banned = room.broadcast.effectiveLiveStatus == LiveStatus.banned;
      return RoomProbe(
        outcome: banned ? ProbeOutcome.unavailable : ProbeOutcome.offline,
        roomTitle: title,
        anchorName: anchor,
      );
    }

    final playback = site?.capability<LivePlaybackProvider>();
    if (playback == null) {
      return RoomProbe(outcome: ProbeOutcome.unavailable, roomTitle: title, anchorName: anchor, detail: '平台不支持解析播放地址');
    }

    final lines = await playback
        .getLines(roomId: target.roomId)
        .then((value) => value.fold((error) => <LivePlayLine>[], (lines) => lines));
    final url = _preferredLine(lines)?.url;

    if (url == null) {
      return RoomProbe(outcome: ProbeOutcome.unknown, roomTitle: title, anchorName: anchor, detail: '房间在播但没有可用的播放地址');
    }

    return RoomProbe(outcome: ProbeOutcome.live, streamUrl: url, roomTitle: title, anchorName: anchor);
  }

  /// The line a capture opens on: the platform's own line labelled with the
  /// recording quality preference when the site names its lines, otherwise
  /// the first — sites order best first, which is what "原画" asks for.
  LivePlayLine? _preferredLine(List<LivePlayLine> lines) {
    final quality = settingsOf().defaultQuality;
    for (final line in lines) {
      final label = line.lineLabel?.trim();
      if (label != null && label.isNotEmpty && label.contains(quality) && line.url.trim().isNotEmpty) {
        return line;
      }
    }
    return lines.where((line) => line.url.trim().isNotEmpty).firstOrNull;
  }

  @override
  Future<RecordCapture> openCapture({required RecordTask task, required String streamUrl}) async {
    final settings = settingsOf();
    final capture = await BackendRecordCapture.start(
      task: task,
      streamUrl: streamUrl,
      config: FfmpegRecordConfig.defaults.copyWith(
        segmentTime: settings.clampedSegmentMinutes * 60,
        rwTimeout: settings.rwTimeout,
        threadQueueSize: settings.threadQueueSize,
        preferBestStream: settings.preferBestStream,
      ),
    );
    if (settings.recordDanmaku) {
      await _attachChat(task: task, capture: capture, includeGifts: settings.recordDanmakuGifts);
    }
    return capture;
  }

  /// The saved chat beside the recording ("录制弹幕"): the room's own danmaku
  /// session written to the session directory until the capture ends. A
  /// failure attaches nothing — the recording itself must not hinge on the
  /// chat.
  Future<void> _attachChat({required RecordTask task, required RecordCapture capture, required bool includeGifts}) async {
    final site = registry.getById(task.target.platform);
    if (site == null) {
      return;
    }
    final writer = await RecordChatWriter.attach(
      site: site,
      roomId: task.target.roomId,
      sessionDirectory: task.paths.sessionDirectory,
      taskId: task.taskId,
      includeGifts: includeGifts,
    );
    if (writer == null) {
      return;
    }
    // The capture's own end closes the file: whether the stream dropped, the
    // room closed or the host stopped it, the chat ends with the media.
    unawaited(capture.ended.then((_) => writer.close()).catchError((_) {}));
  }

  @override
  Future<RecordGuard?> acquireGuard({required RecordTask task}) async {
    // The capture holds its own keep-alive lease for as long as it runs
    // (a wake lock where the platform offers one), and a second holder would
    // only double the notifications.
    return null;
  }

  @override
  Future<void> notify(RecordNotice notice) async {
    // The kernel composes the line; the app's own notification sink shows
    // it when one is wired. Without a sink — and when the platform's
    // notification surface refuses — the notice is accepted and dropped:
    // a notification that is not shown must never stall or fail the
    // recording.
    final onNotice = this.onNotice;
    if (onNotice == null) {
      return;
    }
    final detail = notice.detail;
    try {
      await onNotice('Pure Live · 录制', detail == null ? notice.text : '${notice.text}\n$detail');
    } on Object {
      // Swallowed by the rule above: the recording is the product, the
      // toast is the courtesy.
    }
  }
}

/// One recorder session: the orchestrator plus the session it opened.
///
/// The naming layer lives inside the orchestrator and is fixed there — a
/// changed output root is answered by re-opening the runtime, which the
/// recorder providers do.
final class RecorderRuntime {
  RecorderRuntime._({required this.orchestrator});

  /// Opens a runtime over [slots], restoring what a previous run left
  /// (joining unmerged segments, applying owed display names) before it
  /// answers.
  ///
  /// [policy] and [naming] are held by reference, not copied: the recorder
  /// providers write the live answers into them when the settings change, so
  /// an edit reaches the next decision without re-opening — and re-opening
  /// would stop the recordings that are running.
  static Future<RecorderRuntime> open({
    required RecordServices services,
    required RecordSlotIo slots,
    required RecordPolicy policy,
    required RecordNaming naming,
  }) async {
    final orchestrator = RecordOrchestrator(
      services: services,
      store: RecordJsonStore(slots),
      naming: naming,
      policy: policy,
    );
    final runtime = RecorderRuntime._(orchestrator: orchestrator);
    await orchestrator.restore();
    return runtime;
  }

  /// The driver behind every answer.
  final RecordOrchestrator orchestrator;

  /// Every known task, oldest first.
  List<RecordTask> get tasks => orchestrator.tasks;

  /// A task as it changes.
  Stream<RecordTask> get onChanged => orchestrator.onChanged;

  /// Starts watching a room, resuming its stored task when there is one.
  Future<RecordTask> watch(RecordTarget target) => orchestrator.watch(target);

  /// Stops watching a room and finishes what was captured.
  Future<void> stopWatching(String taskId) => orchestrator.stopWatching(taskId);

  /// Joins and names a task's segments now, without waiting for the room.
  Future<bool> finishNow(String taskId) => orchestrator.finishNow(taskId);

  /// Stops every watcher; the ledger is already durable.
  Future<void> dispose() => orchestrator.dispose();
}
