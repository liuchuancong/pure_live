import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, FileSystemEntity, FileSystemException, RandomAccessFile;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show HttpProxyRoute;
import 'package:live_sites/live_sites.dart'
    show
        DanmakuBlockList,
        DanmakuMessageGate,
        LiveDanmakuProvider,
        LiveDanmakuSession,
        LiveMessage,
        LivePlayLine,
        LiveRoom,
        SiteIds;
import 'package:media_core/media_core.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_settings.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';
import 'package:pure_live/modules/live/recorder/engine/recording_chat_writer.dart';
import 'package:pure_live/modules/live/recorder/engine/recording_claim.dart';
import 'package:pure_live/modules/live/recorder/engine/recording_finalize_lock.dart';
import 'package:pure_live/modules/live/recorder/engine/recording_take_move.dart';
import 'package:pure_live/modules/live/shield/shield.dart';
import 'package:pure_live/shared/danmaku/danmaku.dart' show danmakuSaveFormatsProvider;

/// How often a running session's byte count is written to its task.
const Duration _kProgressWrite = Duration(seconds: 1);

/// How often recorded chat reaches its files.
const Duration _kChatFlush = Duration(seconds: 2);

/// How long a lost chat connection waits before it is opened again.
const Duration _kChatRetry = Duration(seconds: 30);

/// How long opening a chat connection may take before it counts as failed.
const Duration _kChatTimeout = Duration(seconds: 20);

/// The marker that proves a folder is this app's recording root.
const String _kRecordMarker = '.pure_live_recording_root';

/// How often the cap is re-applied while a recording is writing.
const Duration _kCacheTrimPeriod = Duration(minutes: 1);

/// The failure text a task keeps: one paragraph, never a stack.
String _errorOf(Object error) {
  final line = error.toString().split('\n').first.trim();
  return line.length > 240 ? '${line.substring(0, 240)}…' : line;
}

/// A recording the engine holds open: its manager, the backend that answers
/// for the files, the task it belongs to, and the small machinery that
/// writes progress and guards the size cap.
final class _LiveRecording {
  _LiveRecording({
    required this.manager,
    required this.backend,
    required this.task,
    required this.capBytes,
    required this.root,
    required this.take,
    required this.desiredTake,
    required this.room,
    required this.danmaku,
    required this.claim,
  });

  final RecordingManager manager;
  final FfmpegRecordingBackend backend;
  RecordingTask task;
  final int capBytes;

  /// The room whose chat is recorded, and the site capability that opens a
  /// connection for it. Both null when the platform has no chat.
  final LiveRoom? room;
  final LiveDanmakuProvider? danmaku;

  /// The take's directory and the prefix its video segments use, so the chat
  /// file lands beside them with the same name.
  ///
  /// Both are ASCII on purpose: FFmpeg's native path handling differs per
  /// platform, and a Chinese title in a segment path is one failure this class
  /// can remove before it happens. [desiredTake] is the name the take is given
  /// after capture, by Dart, where Unicode is safe.
  final String root;
  final String take;
  final String desiredTake;

  /// Whether the backend was disposed; the post-record steps need it closed
  /// before they move or rename its files.
  bool managerDisposed = false;

  /// When this take's video began; chat entries are timed from here.
  late DateTime videoStartedAt;

  RecordChatWriter? chat;
  bool chatOpening = false;

  /// The cross-window claim this session holds; released when it ends.
  RandomAccessFile? claim;
  LiveDanmakuSession? chatSession;
  bool chatConnecting = false;
  bool _quieted = false;

  /// The reference's duplicate and backlog gate, kept apart from the room's
  /// display gate so the file holds what was said once.
  final DanmakuMessageGate _chatGate = DanmakuMessageGate();

  /// The shield's rules and the block list built from them, rebuilt when the
  /// rules change rather than on every message.
  ShieldRules? _chatRules;
  DanmakuBlockList? _chatBlockList;

  StreamSubscription<RecordingState>? _states;
  StreamSubscription<LiveMessage>? _chatEvents;
  Timer? _ticker;
  Timer? _chatTicker;
  Timer? _chatRetry;
  int _persistedBytes = 0;
  int _persistedDurationMs = 0;

  /// Progress ticks between free-space probes; sixty one-second ticks are a
  /// minute.
  int diskTicks = 0;
  bool diskChecking = false;
  bool _settling = false;

  Future<void> quiet() async {
    _quieted = true;
    _ticker?.cancel();
    _ticker = null;
    _chatTicker?.cancel();
    _chatTicker = null;
    _chatRetry?.cancel();
    _chatRetry = null;
    await _states?.cancel();
    _states = null;
    await _chatEvents?.cancel();
    _chatEvents = null;
    final session = chatSession;
    chatSession = null;
    try {
      await session?.disconnect();
    } on Object {
      // A chat connection that cannot be closed never affects the video.
    }
    try {
      await session?.dispose();
    } on Object {
      // The session may already be gone with the connection.
    }
    final writer = chat;
    chat = null;
    try {
      await writer?.close();
    } on Object {
      // A chat file that cannot be closed never affects the video.
    }
  }
}

/// What a post-recording finish works on: one take on disk, the names it is
/// meant to end up with, and the two closures that can join its segments and
/// let go of whatever was writing them.
///
/// A capture that just closed and a take a crash left behind are the same job
/// seen from here: [RecorderEngine._endAs] builds one from its session, and
/// [RecorderEngine.retryFinalize] builds one from the folder alone, so the
/// join, the re-encode, the archive and the rename run once rather than
/// living twice.
final class _FinalizeTarget {
  _FinalizeTarget({
    required this.taskId,
    required this.startedAt,
    required this.root,
    required this.takePrefix,
    required this.desiredTake,
    required this.desiredFolder,
    required this.join,
    required this.close,
  });

  /// The task whose entry carries the status.
  final String taskId;

  /// The session this take belongs to; every store write is guarded by it, so
  /// a newer take of the same room is never written over.
  final DateTime startedAt;

  /// The take's directory.
  final String root;

  /// The ASCII prefix the capture files were written under — what the chat
  /// sidecars still carry when the rename comes.
  final String takePrefix;

  /// The name the take is given afterwards; empty keeps [takePrefix].
  final String desiredTake;

  /// The folder under the managed root the take is moved into afterwards —
  /// the day it was taken, the platform, the room (`2026-11-02/douyu/6731182`);
  /// empty leaves it where the capture wrote it.
  final String desiredFolder;

  /// Joins the segments into one file. Null means this folder holds nothing
  /// joinable.
  final Future<FfmpegRemuxResult?> Function({
    required void Function(double? progress) onProgress,
    required void Function(FfmpegExecution execution) onExecution,
  })
  join;

  /// Releases the writer behind the take; a no-op when nothing is open.
  final Future<void> Function() close;
}

/// The recording engine: FFmpeg sessions over `media_core_recording_ffmpeg`.
///
/// One task records at a time — the same room re-recorded is a new take in a
/// new directory, and a second concurrent take is refused rather than
/// started (a real recorder does both; this page drives one room). Each
/// session gets its own backend and manager, so a stop disposes only its
/// own FFmpeg; the task's facts (state, bytes, directory, error) are
/// written through the recording repository as the session moves, which is
/// what the recorder page mirrors.
final class RecorderEngine {
  RecorderEngine(this._ref);

  final Ref _ref;
  final Map<String, _LiveRecording> _sessions = <String, _LiveRecording>{};

  /// Take roots whose segments a join is still reading.
  ///
  /// Cache trimming and clearing skip these: a take leaves [_sessions] the
  /// moment its capture ends, and the join runs after that.
  final Set<String> _finalizing = <String>{};
  final Set<Future<void>> _finalizeTasks = <Future<void>>{};
  final Map<String, FfmpegExecution> _finalizeExecutions = <String, FfmpegExecution>{};
  final Set<String> _finalizeCancelled = <String>{};

  /// Tasks whose finish this engine re-started from the folder alone.
  ///
  /// Only a guard against a double tap: the take is not being captured, and the
  /// finalize lock says whether another window is finishing it.
  final Set<String> _retries = <String>{};
  final FfmpegRecordingTranscoder _transcoder = FfmpegRecordingTranscoder();
  Timer? _cacheTrimTimer;
  Future<int>? _cacheTrim;

  /// Whether the task behind [taskId] is being captured right now.
  bool isRecording(String taskId) => _sessions.containsKey(taskId);

  /// How many captures this engine is writing right now.
  int get activeRecordingCount => _sessions.length;

  /// Cancels the join/transcode currently running for [taskId].
  ///
  /// Returns false when that phase already ended; the next tick shows the
  /// normal result. A cancelled run keeps whatever file it had produced and
  /// finishes the task with the `canceled` warning.
  Future<bool> cancelFinalize(String taskId) async {
    final execution = _finalizeExecutions[taskId];
    if (execution == null || !execution.isRunning) return false;
    _finalizeCancelled.add(taskId);
    try {
      await execution.cancel();
    } on Object {
      return false;
    }
    return true;
  }

  /// Runs the post-recording steps again for a take this app never finished.
  ///
  /// A kill between the capture and the join leaves the segments and the
  /// manifest on disk: the recording itself is safe, only the single file the
  /// viewer asked for is missing. This reads the take back from its own folder
  /// and runs the same join, re-encode, archive and rename that a normal stop
  /// runs — behind the same status, progress and cancellation the card already
  /// shows, and guarded by the same finalize lock, so two windows cannot both
  /// finish one take.
  ///
  /// The join itself is always attempted; that is what was asked for. The
  /// transcode, the delete-originals switch and the cache cap stay as the
  /// settings have them. Answers null when the work began, and the reason it
  /// did not when it did not.
  Future<String?> retryFinalize(RecordingTask task) async {
    if (isRecording(task.id) || task.postProcessing) return 'busy';
    if (!_retries.add(task.id)) return 'busy';
    final root = _takeDirectoryOf(task.filePath);
    if (root == null || !root.existsSync()) {
      _retries.remove(task.id);
      return 'gone';
    }
    final manifest = _manifestOf(root);
    final joined = manifest == null ? _joinedFileOf(root) : null;
    if (manifest == null && joined == null) {
      // Nothing to join, and no half-finished merge either: the take is either
      // already a single file or is not in this folder.
      _retries.remove(task.id);
      return 'nothing';
    }
    final repo = _ref.read(recordingRepositoryProvider).value;
    if (repo == null) {
      _retries.remove(task.id);
      return 'the recordings store is not open';
    }
    if (!await repo.beginPostProcessing(task.id, expectedStartedAt: task.startedAt)) {
      _retries.remove(task.id);
      return 'gone';
    }
    // Exactly one of the two is there: the manifest names the closed segments,
    // and a merged file with no manifest is a join that already ran.
    final prefix = manifest?.prefix ?? _prefixOfJoinedFile(joined!.path);
    final target = _FinalizeTarget(
      taskId: task.id,
      startedAt: task.startedAt,
      root: root.path,
      takePrefix: prefix,
      desiredTake: _desiredTakeName(task, at: task.startedAt.toLocal()),
      desiredFolder: _desiredTakeFolder(task, at: task.startedAt.toLocal()),
      join: ({required onProgress, required onExecution}) async {
        final record = manifest;
        if (record != null) {
          return await FfmpegRecordingRemuxer().run(
            manifest: record,
            directory: root.path,
            onProgress: onProgress,
            onExecution: onExecution,
          );
        }
        // The merge is already there; the finish that died left the name and
        // the archive still to do.
        final done = joined!;
        return FfmpegRemuxResult.alreadyThere(outputPath: done.path, bytesWritten: _sizeOf(done));
      },
      // Nothing was open in this process; the take was only ever a folder.
      close: () async {},
    );
    final settings = _ref.read(recordingSettingsProvider);
    _finalizing.add(p.normalize(root.path));
    final tracked = _finalizeRecording(
      target,
      repository: repo,
      // A retry asks for the single file, whatever the standing switch says.
      combine: true,
      transcode: settings.transcodeAfterCombine,
      transcodeBitrateKbps: settings.transcodeBitrateKbps,
      deleteOriginals: settings.deleteOriginalsAfterCombine,
      trimCache: settings.cacheLimitEnabled,
      diskWatermarkMb: settings.diskWatermarkMb,
      initialWarning: '',
    ).catchError((Object _) {}).whenComplete(() => _retries.remove(task.id));
    _finalizeTasks.add(tracked);
    unawaited(tracked.whenComplete(() => _finalizeTasks.remove(tracked)));
    return null;
  }

  /// The take folder a task points at: the path the engine last wrote is
  /// either the folder itself or a file inside it. Null when the task names
  /// nothing, or nothing there is left.
  Directory? _takeDirectoryOf(String? path) {
    final value = (path ?? '').trim();
    if (value.isEmpty) return null;
    final asDirectory = Directory(value);
    if (asDirectory.existsSync()) return asDirectory;
    if (File(value).existsSync()) return File(value).parent;
    return null;
  }

  /// The manifest inside [root], which names the segments' prefix and the
  /// journals they are listed in; null when the folder holds none.
  FfmpegRecordingManifest? _manifestOf(Directory root) {
    try {
      for (final entity in root.listSync(followLinks: false)) {
        if (entity is! File || !p.basename(entity.path).endsWith('.clock-v1.json')) continue;
        final manifest = FfmpegRecordingManifest.read(entity);
        if (manifest != null && manifest.prefix.isNotEmpty) return manifest;
      }
    } on FileSystemException {
      // A folder that cannot be read is a folder with no manifest.
    }
    return null;
  }

  /// A merged file the interrupted finish left at the take's top level; null
  /// when there is none. `original/` is not searched: what went in there is by
  /// then the capture's own files, not a result.
  File? _joinedFileOf(Directory root) {
    try {
      final found = <File>[];
      for (final entity in root.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.endsWith('.combined.mp4') && !name.endsWith('.transcoded.mp4')) continue;
        if (_sizeOf(entity) > 0) found.add(entity);
      }
      // A transcode is the later product of the two; that is the one to keep.
      for (final file in found) {
        if (p.basename(file.path).endsWith('.transcoded.mp4')) return file;
      }
      return found.isEmpty ? null : found.first;
    } on FileSystemException {
      return null;
    }
  }

  /// The bytes a take's folder holds so far: the segments FFmpeg is writing,
  /// summed for a backend that has not reported a figure yet.
  static Future<int> _directoryBytes(Directory directory) async {
    var total = 0;
    try {
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        try {
          total += await entity.length();
        } on FileSystemException {
          // A segment rotating under the walk is simply not counted this tick.
        }
      }
    } on FileSystemException {
      // A folder removed under the walk answers what it managed to read.
    }
    return total;
  }

  static int _sizeOf(File file) {
    try {
      return file.lengthSync();
    } on FileSystemException {
      return 0;
    }
  }

  /// The capture prefix a merged file's name carries, with the join's and the
  /// transcode's own suffixes taken back off.
  static String _prefixOfJoinedFile(String path) {
    var name = p.basenameWithoutExtension(path);
    for (var round = 0; round < 2; round++) {
      for (final suffix in const ['.transcoded', '.combined']) {
        if (name.endsWith(suffix)) name = name.substring(0, name.length - suffix.length);
      }
    }
    return name;
  }

  /// Whether a capture (or its join) is writing outside [root].
  ///
  /// A take keeps the folder it started in even when the viewer moves the
  /// recording folder; this lets the cache surface say that its figures and
  /// trimming cover the current folder only.
  bool hasActiveOutside(Directory root) {
    final normalized = p.normalize(root.path);
    return _activeRoots.any((active) => !p.equals(normalized, active) && !p.isWithin(normalized, active));
  }

  /// Starts capturing the room [task] names at [line]'s address.
  ///
  /// [refreshUrl] may re-mint the address when the stream drops and the
  /// old one has expired; null keeps re-opening the same address. The
  /// line's headers ride the recording — most platforms answer 403
  /// without their referer. Returns null when the capture began, and the
  /// engine's own words when it did not.
  Future<String?> start(
    RecordingTask task,
    LivePlayLine line, {
    Future<String?> Function()? refreshUrl,
    LiveRoom? room,
    LiveDanmakuProvider? danmaku,
  }) async {
    if (_sessions.containsKey(task.id)) return 'already recording';
    // The permission prompt belongs to the action that needs it.
    unawaited(requestUserNotificationPermission());
    final settings = _ref.read(recordingSettingsProvider);
    // Zero is the viewer lifting the concurrency cap; the queue still holds
    // the waiting takes.
    if (settings.maxTasks > 0 && _sessions.length >= settings.maxTasks) {
      return 'too many recordings (${_sessions.length}/${settings.maxTasks})';
    }
    // Trim completed takes before the new one lands, so the cap accounts for
    // the recording about to start and never touches an active session.
    if (settings.cacheLimitEnabled) await enforceCacheLimit();
    final directory = await _outputDirectory();
    final desiredTake = _desiredTakeName(task);
    // The capture never sees the viewer's title: FFmpeg's path handling is not
    // trustworthy for every script on every platform, and a broken prefix
    // takes the whole take with it. The take is renamed to [desiredTake] once
    // it is closed, by Dart.
    var take = _tempTakeName();
    var root = p.join(directory, take);
    for (var suffix = 2; Directory(root).existsSync() && suffix < 1000; suffix++) {
      take = '${_tempTakeName()}_$suffix';
      root = p.join(directory, take);
    }
    final repo = _ref.read(recordingRepositoryProvider).value;
    if (repo == null) return 'the recordings store is not open';

    final proxy = _effectiveProxy();
    // The certificate decision is made before the take is written down: a
    // bundle the viewer named that is not there any more must fail the start
    // rather than silently record against a trust store they did not choose.
    final caFile = await _ensureCaFile(settings.network.customCaPath);
    if (caFile == null && settings.network.customCaPath.trim().isNotEmpty) return 'custom-ca';

    // The other window check: a claim held by another process means that process
    // is capturing this room, and a second take would write the same row twice.
    final claim = await acquireRecordingClaim(_ref.read(appPathsProvider).recordingClaims, task.id);
    if (claim == null) return 'recording-busy';

    try {
      await repo.save(task.copyWith(state: RecordingTaskState.stopped, startedAt: DateTime.now().toUtc()));
    } on Object {
      // A store that cannot take the stub must not keep the claim: the task
      // would read as busy to this same process for the rest of its life.
      await releaseRecordingClaim(claim);
      rethrow;
    }
    final backend = FfmpegRecordingBackend(
      outputDirectory: root,
      diskSpace: FfmpegDiskSpace.probe,
      urlRefresher: refreshUrl == null ? null : (source) async => await refreshUrl() ?? source.value,
      config: FfmpegRecordConfig(
        filePrefix: take,
        // The capture name stays ASCII; the notification names the room, which
        // is the only part of this a viewer recognises an hour later.
        jobLabel: _jobLabelFor(task),
        includeTimestampPrefix: false,
        proxy: proxy,
        caFile: caFile,
        tlsVerify: settings.network.tlsVerify,
        extensionPicky: task.platform != SiteIds.chzzk,
        // Every tunable the settings surface edits reaches FFmpeg here; a
        // setting that did not would be a switch with no effect.
        segmentTime: settings.segmentSeconds,
        rwTimeout: settings.network.readTimeoutSeconds,
        threadQueueSize: settings.queueSize,
        preferBestStream: settings.preferBestStream,
        keepAlive: settings.keepAlive,
        verifyOutput: settings.verifyOutput,
        verifyPlayability: settings.verifyOutput,
        restartLimit: settings.restartLimit,
        restartBackoff: Duration(seconds: settings.restartBackoffSeconds),
        stallTimeout: Duration(seconds: settings.stallTimeoutSeconds),
        diskWatermarkBytes: settings.diskWatermarkMb * 1024 * 1024,
        container: switch (settings.container) {
          RecordingFileContainer.mpegTs => FfmpegRecordContainer.mpegTs,
          RecordingFileContainer.mp4 => FfmpegRecordContainer.mp4Fragmented,
        },
      ),
    );
    final manager = RecordingManager(
      backend: backend,
      config: RecordingConfig(outputPath: root),
    );
    final session = _LiveRecording(
      manager: manager,
      backend: backend,
      task: task,
      capBytes: settings.maxSizeMb * 1024 * 1024,
      root: root,
      take: take,
      desiredTake: desiredTake,
      room: room,
      danmaku: danmaku,
      claim: claim,
    );
    _sessions[task.id] = session;

    try {
      await manager.start(
        // The title stays off the source: the backend names files after it
        // when it is set, and the naming template is the one the viewer
        // chose — the rendered prefix carries both, title included. The
        // line's headers ride along: most platforms answer 403 without
        // their referer, and the proxy's `Proxy-Authorization` belongs in the
        // same place — FFmpeg's `-http_proxy` carries no credential itself.
        source: RecordingSource(
          type: RecordingSourceType.network,
          value: line.url,
          id: task.id,
          headers: {...line.headers.toMap(), 'Proxy-Authorization': ?_proxyAuthorization()},
        ),
      );
    } on Object catch (error) {
      await session.quiet();
      _sessions.remove(task.id);
      await releaseRecordingClaim(session.claim);
      unawaited(manager.dispose());
      await repo.setEnded(task.id, RecordingTaskState.failed, errorText: _errorOf(error));
      return 'cannot start: ${_errorOf(error)}';
    }

    await repo.setRunning(task.id, takeDirectory: root);
    // The store's running entry is the session's truth, including the start
    // the repository stamped; a later join guards its file update on it.
    session
      ..task = repo.taskById(task.id) ?? session.task
      ..videoStartedAt = DateTime.now()
      .._states = backend.onStateChanged.listen((state) => unawaited(_onState(task.id, state)))
      .._ticker = Timer.periodic(_kProgressWrite, (_) => unawaited(_writeProgress(task.id)));
    if (settings.recordDanmaku) unawaited(_openChat(session));
    _ensureCacheTrimTimer();
    return null;
  }

  /// Opens the chat file and its own platform connection for [session].
  Future<void> _openChat(_LiveRecording session) async {
    await _ensureChatFile(session);
    await _connectChat(session);
  }

  /// Creates the take's chat files once, one per saved format; the switch read
  /// per message lets a recording already running pick them up when it is
  /// turned on.
  Future<void> _ensureChatFile(_LiveRecording session) async {
    if (session.chat != null || session.chatOpening || session._quieted) return;
    session.chatOpening = true;
    try {
      final writer = await RecordChatWriter.open(
        p.join(session.root, session.take),
        startedAt: session.videoStartedAt,
        formats: _ref.read(danmakuSaveFormatsProvider),
      );
      if (session._quieted || !_sessions.containsKey(session.task.id)) {
        await writer.close();
        return;
      }
      session
        ..chat = writer
        .._chatTicker = Timer.periodic(_kChatFlush, (_) => unawaited(writer.flush().catchError((Object _) {})));
    } on Object {
      // A chat file that cannot be opened never affects the video.
    } finally {
      session.chatOpening = false;
    }
  }

  /// Opens the recording's own chat connection (the reference's task chat,
  /// independent of the room page), retrying a failed or ended one.
  Future<void> _connectChat(_LiveRecording session) async {
    if (session._quieted || session.chatConnecting || session.chatSession != null) return;
    if (!_ref.read(recordingSettingsProvider).recordDanmaku) return;
    final provider = session.danmaku;
    final room = session.room;
    if (provider == null || room == null) return;
    session.chatConnecting = true;
    try {
      final answer = await provider.createSession(room: room).timeout(_kChatTimeout);
      final created = answer.match<LiveDanmakuSession?>((_) => null, (opened) => opened);
      if (session._quieted || !_ref.read(recordingSettingsProvider).recordDanmaku) {
        await created?.dispose();
        return;
      }
      if (created == null) {
        _scheduleChatRetry(session);
        return;
      }
      session.chatSession = created;
      session._chatEvents = created.events.listen(
        (message) => _recordChatMessage(session, message),
        onDone: () => unawaited(_dropChatSession(session, retry: true)),
        onError: (Object _) {},
      );
      await created.connect().timeout(_kChatTimeout);
      if (session._quieted || !_ref.read(recordingSettingsProvider).recordDanmaku) {
        await _dropChatSession(session, retry: false);
        return;
      }
    } on Object {
      await _dropChatSession(session, retry: true);
    } finally {
      session.chatConnecting = false;
    }
  }

  void _scheduleChatRetry(_LiveRecording session) {
    if (session._quieted || !_ref.read(recordingSettingsProvider).recordDanmaku) return;
    session._chatRetry?.cancel();
    session._chatRetry = Timer(_kChatRetry, () => unawaited(_connectChat(session)));
  }

  Future<void> _dropChatSession(_LiveRecording session, {required bool retry}) async {
    final events = session._chatEvents;
    session._chatEvents = null;
    await events?.cancel();
    final ended = session.chatSession;
    session.chatSession = null;
    try {
      await ended?.disconnect();
    } on Object {
      // A connection that is already gone owns nothing to release.
    }
    try {
      await ended?.dispose();
    } on Object {
      // The session may already be gone with the connection.
    }
    if (retry) {
      _scheduleChatRetry(session);
    } else {
      session._chatRetry?.cancel();
      session._chatRetry = null;
    }
  }

  /// The settings surface's switch: turning it on opens the file and
  /// connection for recordings already running; turning it off closes the
  /// connection and stops adding entries (the file keeps what it has).
  void setChatRecording({required bool enabled}) {
    for (final session in _sessions.values.toList()) {
      if (enabled) {
        unawaited(_openChat(session));
      } else {
        unawaited(_dropChatSession(session, retry: false));
      }
    }
  }

  /// Writes one platform chat line into the take's XML; the shield's block
  /// lists and the duplicate gate run as the reference's recording
  /// connection does, while the display-only filters stay out.
  void _recordChatMessage(_LiveRecording session, LiveMessage message) {
    if (session._quieted) return;
    final settings = _ref.read(recordingSettingsProvider);
    if (!settings.recordDanmaku) return;
    if (!recordableDanmaku(message.type, includeGifts: settings.recordDanmakuGifts)) return;
    final writer = session.chat;
    if (writer == null) return;
    final rules = _ref.read(shieldRulesProvider);
    if (!identical(rules, session._chatRules)) {
      session
        .._chatRules = rules
        .._chatBlockList = DanmakuBlockList.of(users: rules.users, keywords: rules.keywords);
    }
    if (rules.enabled && (session._chatBlockList?.blocks(message) ?? false)) return;
    final now = DateTime.now();
    if (!session._chatGate.accepts(message, now: now)) return;
    try {
      writer.add(message, receivedAt: now);
    } on Object {
      // A failing chat file never affects the recording.
    }
  }

  /// Ends the session behind [taskId] as a user stop (its segments stay)
  /// and reports what it wrote. Returns the engine's words when nothing
  /// recorded or the end itself failed.
  Future<String?> stop(String taskId, {String warning = ''}) async {
    final session = _sessions[taskId];
    if (session == null) return 'not recording';
    if (session._settling) return null;
    session._settling = true;
    await session.quiet();
    RecordingResult result;
    try {
      result = await session.manager.stop();
    } on Object catch (error) {
      await _endAs(session, failed: true, errorText: _errorOf(error));
      return 'cannot stop: ${_errorOf(error)}';
    }
    await _persist(
      session,
      success: result.success,
      bytes: result.bytesWritten,
      durationMs: result.duration.inMilliseconds,
      errorText: result.error == null ? '' : _errorOf(result.error!),
      warning: warning,
    );
    return null;
  }

  /// Ends every session the engine still holds (app shutdown), and waits for
  /// the joins already running so a half-written MP4 is not left behind.
  Future<void> dispose() async {
    _cacheTrimTimer?.cancel();
    _cacheTrimTimer = null;
    for (final taskId in _sessions.keys.toList()) {
      await stop(taskId);
    }
    for (final task in _finalizeTasks.toList()) {
      await task;
    }
  }

  /// A terminal state the backend reached on its own — a stream that gave
  /// up, an input that ran out. The user's stop path cancels this
  /// listener first, so only the unsolicited ends arrive here.
  Future<void> _onState(String taskId, RecordingState state) async {
    final session = _sessions[taskId];
    if (session == null || session._settling || !state.status.isTerminal) return;
    session._settling = true;
    await session.quiet();
    final check = session.backend.lastCheck;
    final usable = state.status == RecordingStatus.completed && (check?.isUsable ?? true);
    await _persist(
      session,
      success: usable,
      bytes: check?.bytesOnDisk ?? state.bytesWritten,
      durationMs: state.duration.inMilliseconds,
      errorText: state.error == null ? '' : _errorOf(state.error!),
    );
  }

  /// The size cap: a recording that reached it is ended by the engine and
  /// saved whole — the reference's behaviour of closing a take rather
  /// than piling files forever.
  Future<void> _writeProgress(String taskId) async {
    final session = _sessions[taskId];
    if (session == null || session._settling) return;
    final state = session.backend.state;
    // The backend names bytes and media time only once it has them: a take
    // still writing its first segment answers zero, which a list reads as
    // "nothing recorded yet". The folder and the wall clock answer instead,
    // so a running row shows its size and rate from the first tick.
    var bytes = state.bytesWritten;
    // While the backend has not answered a size there is nothing to report but
    // the folder itself; a take holds a handful of segments, so a scan a
    // second costs less than a row that shows nothing for ten.
    if (bytes <= 0) {
      final directory = _takeDirectoryOf(session.task.filePath);
      if (directory != null && directory.existsSync()) bytes = await _directoryBytes(directory);
    }
    var durationMs = state.duration.inMilliseconds;
    if (durationMs <= 0) durationMs = DateTime.now().difference(session.videoStartedAt).inMilliseconds;
    // The UI needs the size every second; the store does not need a row write
    // for every tick. A changed size is written at once, a length that only
    // moved with the clock every five seconds.
    final bytesMoved = bytes != session._persistedBytes;
    final durationMoved = (durationMs - session._persistedDurationMs).abs() >= 5000;
    if (bytesMoved || durationMoved) {
      session
        .._persistedBytes = bytes
        .._persistedDurationMs = durationMs;
      final repo = _ref.read(recordingRepositoryProvider).value;
      await repo?.setProgress(taskId, bytes, durationMs: durationMs);
    }
    if (session.capBytes > 0 && bytes >= session.capBytes) await stop(taskId);
    // A take that outlives the free-space check at start is caught here: once
    // a minute is often enough to stop before the disk fills, and cheap enough
    // to run beside the progress write.
    final watermark = _ref.read(recordingSettingsProvider).diskWatermarkMb;
    if (watermark > 0 && !session.diskChecking && ++session.diskTicks % 60 == 0) {
      session.diskChecking = true;
      unawaited(_checkFreeSpace(session, watermark));
    }
  }

  /// Stops a take when the volume cannot hold another watermark's worth.
  Future<void> _checkFreeSpace(_LiveRecording session, int watermarkMb) async {
    try {
      final free = await FfmpegDiskSpace.probe(session.root);
      if (free == null || !_sessions.containsKey(session.task.id)) return;
      if (free < watermarkMb * 1024 * 1024) {
        await stop(session.task.id, warning: 'disk-low');
      }
    } on Object {
      // A probe that cannot answer is not evidence of a full disk.
    } finally {
      session.diskChecking = false;
    }
  }

  Future<void> _persist(
    _LiveRecording session, {
    required bool success,
    required int bytes,
    required int durationMs,
    required String errorText,
    String warning = '',
  }) async {
    await _endAs(
      session,
      failed: !success,
      errorText: errorText,
      bytes: bytes,
      durationMs: durationMs,
      warning: warning,
    );
  }

  Future<void> _endAs(
    _LiveRecording session, {
    required bool failed,
    required String errorText,
    int? bytes,
    int? durationMs,
    String warning = '',
  }) async {
    _sessions.remove(session.task.id);
    await releaseRecordingClaim(session.claim);
    final repo = _ref.read(recordingRepositoryProvider).value;
    final directory = session.backend.activeDirectory ?? '';
    await repo?.setEnded(
      session.task.id,
      failed ? RecordingTaskState.failed : RecordingTaskState.stopped,
      filePath: directory.isEmpty ? null : directory,
      bytes: bytes,
      durationMs: durationMs,
      errorText: errorText,
      postProcessing: !failed,
      warning: failed ? '' : warning,
    );
    final settings = _ref.read(recordingSettingsProvider);
    if (!failed) {
      // The task is already saved and visible; the join/transcode/rename
      // happen behind it. The settings and the store are read here, while the
      // engine is alive.
      _finalizing.add(p.normalize(session.root));
      final target = _FinalizeTarget(
        taskId: session.task.id,
        startedAt: session.task.startedAt,
        root: session.root,
        takePrefix: session.take,
        desiredTake: session.desiredTake,
        desiredFolder: _desiredTakeFolder(session.task, at: session.task.startedAt.toLocal()),
        join: ({required onProgress, required onExecution}) =>
            session.backend.combineLastRecording(onProgress: onProgress, onExecution: onExecution),
        close: () => _disposeManager(session),
      );
      final finish = _finalizeRecording(
        target,
        repository: repo,
        combine: settings.combineAfterStop,
        transcode: settings.transcodeAfterCombine,
        transcodeBitrateKbps: settings.transcodeBitrateKbps,
        deleteOriginals: settings.deleteOriginalsAfterCombine,
        trimCache: settings.cacheLimitEnabled,
        diskWatermarkMb: settings.diskWatermarkMb,
        initialWarning: warning,
      );
      final tracked = finish.catchError((Object _) {});
      _finalizeTasks.add(tracked);
      unawaited(tracked.whenComplete(() => _finalizeTasks.remove(tracked)));
    } else {
      unawaited(_disposeManager(session));
      // The finished take is no longer protected: apply the cap at once
      // instead of waiting for the next recording or the minute.
      if (settings.cacheLimitEnabled) trimCacheQuietly();
      _stopCacheTrimIfIdle();
    }
  }

  /// Turns a finished take into the file and name the viewer asked for.
  ///
  /// The capture is saved before this runs, so a failed join/transcode leaves
  /// the segments exactly as written. The take is always renamed, because the
  /// capture used an ASCII temporary name; a join and an optional re-encode
  /// happen first so the final name is applied to the file that survives.
  Future<void> _finalizeRecording(
    _FinalizeTarget target, {
    required RecordingTaskRepository? repository,
    required bool combine,
    required bool transcode,
    required int transcodeBitrateKbps,
    required bool deleteOriginals,
    required bool trimCache,
    required int diskWatermarkMb,
    required String initialWarning,
  }) async {
    final root = Directory(target.root);
    if (!root.existsSync()) {
      _finalizing.remove(p.normalize(target.root));
      await repository?.finishPostProcessing(target.taskId, expectedStartedAt: target.startedAt, warning: 'stale');
      await target.close();
      if (trimCache) trimCacheQuietly();
      _stopCacheTrimIfIdle();
      return;
    }
    final lock = await acquireFinalizeLock(root);
    if (lock == null) {
      // Another process owns this take's finalize; it will write the status.
      _finalizing.remove(p.normalize(target.root));
      await target.close();
      if (trimCache) trimCacheQuietly();
      _stopCacheTrimIfIdle();
      return;
    }
    var warning = initialWarning;
    var lowDisk = initialWarning == 'disk-low';
    if (!lowDisk && diskWatermarkMb > 0) {
      final free = await FfmpegDiskSpace.probe(root.path);
      if (free != null && free < diskWatermarkMb * 1024 * 1024) {
        lowDisk = true;
        warning = 'disk-low';
      }
    }
    var released = false;
    Future<void> release() async {
      if (released) return;
      released = true;
      await releaseFinalizeLock(lock, root);
    }

    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    var progressWrites = Future<void>.value();
    void onProgress(double? progress) {
      final now = DateTime.now();
      if (now.difference(lastProgressAt) < const Duration(seconds: 1)) return;
      lastProgressAt = now;
      final store = repository;
      if (store == null) return;
      progressWrites = progressWrites.then((_) async {
        await store.setPostProcessingProgress(
          target.taskId,
          expectedStartedAt: target.startedAt,
          progress: progress ?? -1,
        );
      });
    }

    void onExecution(FfmpegExecution execution) {
      _finalizeExecutions[target.taskId] = execution;
    }

    try {
      var singleFileHandled = false;
      String? finalFile;
      int? finalBytes;
      // A take stopped for low disk must not write a second copy: the join and
      // transcode are skipped, and the segments are kept.
      if (combine && !lowDisk) {
        FfmpegRemuxResult? joined;
        FfmpegRemuxResult? joinResult;
        try {
          joinResult = await target.join(onProgress: onProgress, onExecution: onExecution);
          if (joinResult != null && joinResult.success && joinResult.bytesWritten > 0) joined = joinResult;
        } on Object {
          // A join that could not run leaves the segments as the recording.
        }
        _finalizeExecutions.remove(target.taskId);
        if (joined == null) {
          warning = 'join-failed';
          final partial = joinResult?.outputPath ?? '';
          if (partial.isNotEmpty) {
            try {
              final file = File(partial);
              if (file.existsSync()) file.deleteSync();
            } on FileSystemException {
              // A partial join is cache-cleared later.
            }
          }
        } else {
          var source = joined.outputPath;
          var bytes = joined.bytesWritten;
          if (transcode) {
            final output = _transcodedPathOf(source);
            final result = await _transcoder.run(
              inputPath: source,
              outputPath: output,
              config: FfmpegTranscodeConfig(videoBitrateKbps: transcodeBitrateKbps),
              onProgress: onProgress,
              onExecution: onExecution,
            );
            _finalizeExecutions.remove(target.taskId);
            if (result.success && result.bytesWritten > 0) {
              source = result.outputPath;
              bytes = result.bytesWritten;
            } else {
              warning = 'transcode-failed';
            }
          }
          await target.close();
          await _archiveOriginals(target, keepPath: source, delete: deleteOriginals);
          await release();
          final renamed = await _renameTake(target, sourceFile: source);
          finalFile = renamed.filePath;
          finalBytes = bytes;
          singleFileHandled = true;
          await repository?.setFinalPath(
            target.taskId,
            expectedStartedAt: target.startedAt,
            filePath: finalFile ?? renamed.directory,
            bytes: finalBytes,
          );
        }
      }
      if (_finalizeCancelled.remove(target.taskId)) warning = 'canceled';
      if (!singleFileHandled) {
        // No usable single file (or the join is off): the folder itself is
        // what the take is, and its title still belongs on it.
        await target.close();
        await release();
        final renamed = await _renameTake(target);
        await repository?.setFinalPath(target.taskId, expectedStartedAt: target.startedAt, filePath: renamed.directory);
      }
    } on Object {
      if (warning.isEmpty) warning = 'finalize-failed';
    } finally {
      await release();
      // Let the last progress write land before the finish clears it; a late
      // write after `postProcessing: false` would otherwise restore a stale
      // flag.
      try {
        await progressWrites;
      } on Object {
        // A progress write that cannot land does not change the result.
      }
      _finalizeExecutions.remove(target.taskId);
      _finalizeCancelled.remove(target.taskId);
      _finalizing.remove(p.normalize(target.root));
      await repository?.finishPostProcessing(target.taskId, expectedStartedAt: target.startedAt, warning: warning);
      await target.close();
      if (trimCache) trimCacheQuietly();
      _stopCacheTrimIfIdle();
    }
  }

  Future<void> _disposeManager(_LiveRecording session) async {
    if (session.managerDisposed) return;
    session.managerDisposed = true;
    try {
      await session.manager.dispose();
    } on Object {
      // A manager already gone owns nothing to release.
    }
  }

  /// Where the re-encoded file is written beside its source.
  static String _transcodedPathOf(String source) {
    final directory = p.dirname(source);
    final name = p.basenameWithoutExtension(source);
    return p.join(directory, '$name.transcoded.mp4');
  }

  /// Moves the capture files out of the way of the file that is kept.
  ///
  /// With [delete] off they go under `original/`, so a bad transcode can be
  /// retried and nothing is lost; with it on everything except [keepPath] is
  /// deleted. The kept file is excluded either way: it is the recording the
  /// viewer asked for.
  Future<void> _archiveOriginals(_FinalizeTarget target, {required String keepPath, required bool delete}) async {
    final root = Directory(target.root);
    if (!root.existsSync()) return;
    final List<FileSystemEntity> entries;
    try {
      entries = root.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    final keep = p.normalize(keepPath);
    if (delete) {
      for (final entity in entries.whereType<File>()) {
        if (p.normalize(entity.path) == keep) continue;
        if (p.basename(entity.path) == kFinalizeLockName) continue;
        if (_isChatSidecar(target, p.basename(entity.path))) continue;
        try {
          entity.deleteSync();
        } on FileSystemException {
          // A locked file stays; the cache clear can remove it later.
        }
      }
      return;
    }
    try {
      final original = Directory(p.join(target.root, 'original'));
      if (!original.existsSync()) await original.create(recursive: true);
      for (final entity in entries) {
        if (entity is! File || p.normalize(entity.path) == keep) continue;
        if (p.basename(entity.path) == kFinalizeLockName) continue;
        // The chat is part of the take, not a capture intermediate: it stays
        // beside the final file under the same name.
        if (_isChatSidecar(target, p.basename(entity.path))) continue;
        try {
          await entity.rename(p.join(original.path, p.basename(entity.path)));
        } on FileSystemException {
          // The kept file is what matters; a file that cannot move stays.
        }
      }
    } on FileSystemException {
      // Keeping the originals beside the kept file is harmless.
    }
  }

  /// The extensions [RecordChatWriter] writes, one file per format.
  static const Set<String> _chatExtensions = {'xml', 'json', 'ass', 'srt', 'txt'};

  /// Whether [name] is one of the take's chat sidecars.
  bool _isChatSidecar(_FinalizeTarget target, String name) {
    for (final extension in _chatExtensions) {
      if (name == '${target.takePrefix}.$extension') return true;
    }
    return false;
  }

  /// Stops the cache clock once no capture and no join is using the folder.
  void _stopCacheTrimIfIdle() {
    if (_sessions.isNotEmpty || _finalizing.isNotEmpty) return;
    _cacheTrimTimer?.cancel();
    _cacheTrimTimer = null;
  }

  void _ensureCacheTrimTimer() {
    _cacheTrimTimer ??= Timer.periodic(_kCacheTrimPeriod, (_) {
      if (_ref.read(recordingSettingsProvider).cacheLimitEnabled) trimCacheQuietly();
    });
  }

  /// Applies the cap without surfacing a failure: a locked file is retried by
  /// the next start, tick or setting change.
  void trimCacheQuietly() {
    try {
      unawaited(enforceCacheLimit().then<void>((_) {}, onError: (Object _) {}));
    } on Object {
      // A disposed engine owns no cache to trim.
    }
  }

  /// Where recordings land: the folder this app owns for them, created on
  /// demand. A folder that cannot be made fails the take — the engine has no
  /// second place to put a recording.
  Future<String> _outputDirectory() async => (await _managedRoot()).path;

  /// The folder this app owns for recordings: the storage layout's answer with
  /// the viewer's own choice laid over it. It carries an ownership marker so
  /// clearing and trimming stay inside what the app made and never reach a
  /// folder the viewer pointed it at by mistake.
  Future<Directory> _managedRoot() async {
    final root = _ref.read(appPathsProvider).recordings;
    await root.create(recursive: true);
    final marker = File(p.join(root.path, _kRecordMarker));
    if (!marker.existsSync()) {
      await marker.writeAsString('Pure Live managed recording directory.\n', flush: true);
    }
    return root;
  }

  /// The roots of takes still being written or joined; cache work skips them.
  Iterable<String> get _activeRoots => [
    ..._sessions.values.map((session) => p.normalize(session.root)),
    ..._finalizing,
  ];

  bool _isActive(String path) {
    final normalized = p.normalize(path);
    return _activeRoots.any((root) => p.equals(root, normalized) || p.isWithin(root, normalized));
  }

  Future<int> _folderBytes(Directory folder) => folderBytes(folder, exclude: {_kRecordMarker});

  /// Whether the shared task store says another engine is recording. That
  /// engine's take lives in the same managed folder but is not in this
  /// process's `_sessions`, so cache work must stand down rather than risk
  /// deleting it.
  bool get _hasForeignRecording => _ref
      .read(recordingTasksProvider)
      .tasks
      .any(
        (task) =>
            (task.state == RecordingTaskState.recording || task.postProcessing) && !_sessions.containsKey(task.id),
      );

  /// The settled takes the current recording folder does not hold.
  ///
  /// The list [moveStrandedTakes] brings home: [strandedTasksOf] over what the
  /// store says, read here rather than on the page because a move is the
  /// engine's own work. A take still being captured or finished is never in it,
  /// whoever owns it.
  List<RecordingTask> _strandedTakes() =>
      strandedTasksOf(_ref.read(recordingTasksProvider).tasks, _ref.read(appPathsProvider).recordings.path);

  /// Brings home every settled take the current folder does not hold.
  ///
  /// Same volume, the folder is renamed: one directory entry changes and no
  /// byte is touched. Across volumes the take is copied file by file, the copy
  /// is measured against the source, and only a copy that matches has its
  /// source deleted — and the task row is pointed at the new copy **before**
  /// anything is removed, so a half-finished delete cannot leave the viewer
  /// with a card that opens nothing. A take that fails or is cancelled keeps
  /// its original folder and its original row.
  ///
  /// [cancelled] is asked between tasks and between the files of one task; a
  /// cancelled copy is discarded rather than left beside the source.
  Future<({int moved, int failed})> moveStrandedTakes({
    void Function(int done, int total, String name)? onProgress,
    bool Function()? cancelled,
  }) async {
    final tasks = _strandedTakes();
    final root = await _managedRoot();
    final repo = _ref.read(recordingRepositoryProvider).value;
    var moved = 0;
    var failed = 0;
    for (var index = 0; index < tasks.length; index++) {
      final task = tasks[index];
      if (cancelled?.call() ?? false) {
        // The rest stay where they are; the page says what was brought over.
        break;
      }
      // A row this process is capturing or finishing is not ours to move, even
      // if the path in it says it lives elsewhere.
      if (isRecording(task.id) || task.postProcessing) continue;
      onProgress?.call(index, tasks.length, _roomLabel(task));
      if (await _moveOneTake(task, root, repo, cancelled: cancelled)) {
        moved++;
      } else {
        failed++;
      }
    }
    onProgress?.call(tasks.length, tasks.length, '');
    if (moved > 0 && _ref.read(recordingSettingsProvider).cacheLimitEnabled) trimCacheQuietly();
    return (moved: moved, failed: failed);
  }

  /// One take across the volume boundary, if it needs to move at all.
  Future<bool> _moveOneTake(
    RecordingTask task,
    Directory root,
    RecordingTaskRepository? repo, {
    bool Function()? cancelled,
  }) async {
    final source = _takeDirectoryOf(task.filePath);
    if (source == null || !source.existsSync()) return false;
    final destination = _uniqueDirectory(root, p.basename(source.path));
    if (p.equals(destination.path, source.path)) return false;
    // First choice: a rename. Same volume it is instant and moves nothing.
    try {
      await source.rename(destination.path);
      await _repointTask(task, repo, from: source.path, to: destination.path);
      return true;
    } on FileSystemException {
      // Not the same volume (or the folder belongs to someone else); copy.
    }
    if (!await _copyTake(source, destination, cancelled: cancelled)) {
      try {
        await destination.delete(recursive: true);
      } on FileSystemException {
        // A destination that cannot be discarded stays as cache.
      }
      return false;
    }
    await _repointTask(task, repo, from: source.path, to: destination.path);
    try {
      await source.delete(recursive: true);
    } on FileSystemException {
      // The verified copy is what the card now opens; a source the system
      // still holds (a player, an indexer) is left for a later clear.
    }
    return true;
  }

  /// Copies [source] into [destination] and measures the result; see
  /// [copyTakeVerified] for what "measured" means.
  Future<bool> _copyTake(Directory source, Directory destination, {bool Function()? cancelled}) =>
      copyTakeVerified(source, destination, cancelled: cancelled);

  /// Points a moved take's row at its new home, keeping the session guard: a
  /// newer take of the same room must not be re-pointed by this move.
  Future<void> _repointTask(
    RecordingTask task,
    RecordingTaskRepository? repo, {
    required String from,
    required String to,
  }) async {
    final rebased = rebaseTakePath(task.filePath ?? '', from: from, to: to);
    await repo?.setFinalPath(task.id, expectedStartedAt: task.startedAt, filePath: rebased);
  }

  /// The name the merge progress line shows for a task.
  static String _roomLabel(RecordingTask task) {
    final title = task.roomTitle.trim();
    return title.isEmpty ? task.id : title;
  }

  /// The managed folder's bytes, active takes included.
  Future<int> cacheBytes() async {
    final root = await _managedRoot();
    return await _folderBytes(root);
  }

  /// Deletes every finished managed file and empty folder; active recordings
  /// and the ownership marker stay. Answers the bytes left.
  Future<int> clearCache() async {
    final root = await _managedRoot();
    if (_hasForeignRecording) return await _folderBytes(root);
    final entities = <FileSystemEntity>[];
    try {
      // The stream is awaited so the walk yields between entries; a tear-off
      // forEach would buffer it without that yield.
      // ignore: prefer_foreach
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        entities.add(entity);
      }
    } on FileSystemException {
      return await _folderBytes(root);
    }
    // Sequential by design: thousands of deletes issued at once would fight
    // the filesystem rather than finish sooner.
    for (final entity in entities.whereType<File>()) {
      if (p.basename(entity.path) == _kRecordMarker || _isActive(entity.path)) continue;
      try {
        await entity.delete();
      } on FileSystemException {
        // A file rotating or locked keeps its share; the next clear retries.
      }
    }
    final directories = entities.whereType<Directory>().toList()
      ..sort((left, right) => right.path.length.compareTo(left.path.length));
    for (final directory in directories) {
      if (_isActive(directory.path)) continue;
      try {
        final contents = await directory.list(followLinks: false).toList();
        if (contents.isEmpty) await directory.delete();
      } on FileSystemException {
        // Non-empty or in use.
      }
    }
    return await _folderBytes(root);
  }

  /// Applies the configured cap to finished files, oldest first; active
  /// recordings count toward the total but are never deleted. A disabled cap
  /// only measures. Answers the bytes left.
  Future<int> enforceCacheLimit() {
    final pending = _cacheTrim;
    if (pending != null) return pending;
    late final Future<int> operation;
    operation = _runCacheTrim().whenComplete(() {
      if (identical(_cacheTrim, operation)) _cacheTrim = null;
    });
    _cacheTrim = operation;
    return operation;
  }

  Future<int> _runCacheTrim() async {
    final settings = _ref.read(recordingSettingsProvider);
    final root = await _managedRoot();
    var total = await _folderBytes(root);
    if (!settings.cacheLimitEnabled || _hasForeignRecording) return total;
    final limit = settings.cacheLimitMb * 1024 * 1024;
    if (total <= limit) return total;
    final entries = <({File file, int size, DateTime modified})>[];
    try {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File || p.basename(entity.path) == _kRecordMarker) continue;
        if (_isActive(entity.path)) continue;
        try {
          // Deliberately asynchronous: the walk must yield between entries on
          // a folder with thousands of segments.
          // ignore: avoid_slow_async_io
          final stat = await entity.stat();
          entries.add((file: entity, size: stat.size, modified: stat.modified));
        } on FileSystemException {
          // Rotated between listing and stat.
        }
      }
    } on FileSystemException {
      return total;
    }
    entries.sort((left, right) => left.modified.compareTo(right.modified));
    for (final entry in entries) {
      if (total <= limit) break;
      try {
        await entry.file.delete();
        total -= entry.size;
      } on FileSystemException {
        // Locked; the next oldest may still fit.
      }
    }
    return total;
  }

  /// The ASCII name a take captures under.
  ///
  /// FFmpeg's native path handling is the one place a Chinese title can break
  /// a capture before a single byte is written, and the segment muxer repeats
  /// that name in every file plus the journal. The capture therefore uses this
  /// name only; the template name is applied by Dart after the take closes.
  String _tempTakeName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return 'rec_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}_${three(now.millisecond)}';
  }

  /// The take's final name: the naming template rendered with the room's
  /// facts, plus a timestamp — two takes of one room must not name themselves
  /// the same. Unicode survives [FfmpegRecordArguments.safeFilePrefix]; the
  /// rename is a Dart filesystem call, which handles it on every platform.
  ///
  /// [at] is the moment the take began: a finish that is re-run later has to
  /// name the take the way the capture would have, not with the retry's clock.
  String _desiredTakeName(RecordingTask task, {DateTime? at}) {
    final now = at ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final template = _ref.read(recordingSettingsProvider).namingTemplate;
    final rendered = template
        .replaceAll('{date}', '${now.year}-${two(now.month)}-${two(now.day)}')
        .replaceAll('{time}', '${two(now.hour)}:${two(now.minute)}:${two(now.second)}')
        .replaceAll('{platform}', task.platform)
        .replaceAll('{roomId}', task.roomId)
        .replaceAll('{title}', task.roomTitle);
    final safe = FfmpegRecordArguments.safeFilePrefix(rendered);
    return safe.isEmpty ? stamp : '${safe}_$stamp';
  }

  /// The folder a finished take lives in, relative to the managed root: the
  /// day the take began, then the platform, then the room — a month of
  /// recordings reads as a calendar, a day as the rooms taken that day, and
  /// a room's takes sit together under it. Each part is made filesystem-safe
  /// the way the take's own name is; a part that comes out empty is skipped
  /// rather than producing an empty folder level.
  String _desiredTakeFolder(RecordingTask task, {DateTime? at}) {
    final now = at ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final day = '${now.year}-${two(now.month)}-${two(now.day)}';
    final parts = [
      day,
      FfmpegRecordArguments.safeFilePrefix(task.platform),
      FfmpegRecordArguments.safeFilePrefix(task.roomId),
    ].where((part) => part.isNotEmpty);
    return p.joinAll(parts);
  }

  /// The name a take's notification shows for [task]: the room's title, which
  /// is what a viewer recognises an hour later — the capture prefix is a
  /// filesystem name. A room whose title the platform never gave falls back to
  /// its identity rather than to a blank line.
  static String _jobLabelFor(RecordingTask task) {
    final title = task.roomTitle.trim();
    return title.isEmpty ? '${task.platform}:${task.roomId}' : title;
  }

  /// The app proxy in the form FFmpeg's HTTP input understands.
  ///
  /// A recording has to take the same route as the player: an account behind
  /// a proxy resolves, while a direct capture from the same machine does not.
  /// Only the manual/system HTTP endpoint is expressible here, and only its
  /// address: FFmpeg's `-http_proxy` reads a bare `host:port` and would fold a
  /// `user:pass@` into the hostname, so an authenticated endpoint rides along as
  /// [_proxyAuthorization] on the source headers instead. A PAC script or a
  /// SOCKS-only proxy still leaves the recording direct.
  String? _effectiveProxy() {
    try {
      if (_ref.read(appProxyRouteProvider) case final HttpProxyRoute route) return route.url();
    } on Object {
      // A network choice that cannot be read is a direct connection.
    }
    return null;
  }

  /// The `Proxy-Authorization` value for the proxy in force, or null.
  ///
  /// Added to the recording source's headers — the channel FFmpeg does send to
  /// its proxy — so a capture behind an authenticated proxy is not the one
  /// consumer left standing outside the network page's choice.
  String? _proxyAuthorization() {
    try {
      if (_ref.read(appProxyRouteProvider) case final HttpProxyRoute route) return route.proxyAuthorizationHeader;
    } on Object {
      return null;
    }
    return null;
  }

  Future<String?>? _caFile;
  String? _caSource;

  /// The CA file FFmpeg is pointed at: the viewer's own bundle when the
  /// recording settings name one, the bundled Mozilla store otherwise.
  ///
  /// The prebuilt library keeps a build-machine certificate path, so a public
  /// HTTPS chain fails verification on a phone unless the host points FFmpeg at
  /// a real bundle. Either way the bytes are staged in the app's persistent
  /// data — a picked file the viewer later moves or deletes cannot then strand a
  /// take, and Android's picked paths are not readable by FFmpeg in place.
  ///
  /// A named file that cannot be read answers null and the cache is dropped, so
  /// the next start re-reads the choice; [RecorderEngine.start] refuses the take
  /// rather than switching the viewer onto a trust store they did not pick.
  /// Concurrent starts share the same future.
  Future<String?> _ensureCaFile(String customPath) {
    final chosen = customPath.trim();
    if (_caFile != null && _caSource == chosen) return _caFile!;
    _caSource = chosen;
    return _caFile = _loadCaFile(chosen);
  }

  Future<String?> _loadCaFile(String customPath) async {
    try {
      final folder = _ref.read(appPathsProvider).certificates;
      await folder.create(recursive: true);
      if (customPath.isNotEmpty) {
        final source = File(customPath);
        if (!source.existsSync()) return null;
        final bytes = await source.readAsBytes();
        // A DER certificate or a stray binary file is not a bundle: OpenSSL
        // would refuse it at the first HTTPS input, which is a worse answer
        // than telling the viewer now.
        if (bytes.isEmpty || !_looksLikePemBundle(bytes)) return null;
        final staged = File(p.join(folder.path, 'custom-ca.pem'));
        // A staged copy is reused only while it is at least as new as the file
        // it came from: the viewer may have replaced the bundle in place, and a
        // length check alone would keep serving the old roots. These are
        // metadata reads on a path that runs once per start, so the synchronous
        // calls are the honest ones here.
        final fresh =
            staged.existsSync() &&
            staged.lengthSync() == bytes.length &&
            staged.lastModifiedSync().isAfter(source.lastModifiedSync());
        if (!fresh) await staged.writeAsBytes(bytes, flush: true);
        return staged.path;
      }
      final data = await rootBundle.load('assets/certs/cacert.pem');
      final file = File(p.join(folder.path, 'cacert.pem'));
      if (!file.existsSync() || file.lengthSync() != data.lengthInBytes) {
        await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
      return file.path;
    } on Object {
      return null;
    }
  }

  /// Whether [bytes] reads like PEM text with at least one certificate in it.
  static bool _looksLikePemBundle(List<int> bytes) {
    if (bytes.isEmpty) return false;
    // A bundle is ASCII text; scanning the first kilobyte for the PEM marker is
    // enough to tell a certificate from a DER blob or a stray binary file.
    final head = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    return utf8.decode(head, allowMalformed: true).contains('-----BEGIN CERTIFICATE-----');
  }

  /// A directory under [parent] named [name], with a suffix when that name is
  /// already taken by another take. [keep] is the take's own folder: a name it
  /// already carries is not a collision, it is this take.
  Directory _uniqueDirectory(Directory parent, String name, {Directory? keep}) {
    var candidate = Directory(p.join(parent.path, name));
    for (var suffix = 2; candidate.existsSync() && !p.equals(candidate.path, keep?.path ?? ''); suffix++) {
      if (suffix >= 1000) break;
      candidate = Directory(p.join(parent.path, '${name}_$suffix'));
    }
    return candidate;
  }

  /// Renames the finished take to its template name and, when it has a single
  /// file, that file too. Answers the take's final directory and file.
  ///
  /// The folder rename is attempted first so the file moves with it; when the
  /// folder is locked, the file is still given its final name inside the
  /// temporary folder, which is the part the viewer opens.
  Future<({String directory, String? filePath})> _renameTake(_FinalizeTarget target, {String? sourceFile}) async {
    final desired = target.desiredTake.isEmpty ? target.takePrefix : target.desiredTake;
    final oldRoot = Directory(target.root);
    if (!oldRoot.existsSync()) {
      return (directory: target.root, filePath: sourceFile);
    }
    var root = oldRoot;
    // The take moves under its day/platform/room folder of the managed root
    // it was written in. A take that is not inside the managed root (an old
    // directory being finished after the viewer moved it) stays beside its
    // siblings instead of crossing into the new root — a rename across
    // volumes would fail anyway.
    var parent = oldRoot.parent;
    if (target.desiredFolder.isNotEmpty) {
      final managed = await _managedRoot();
      if (p.isWithin(p.normalize(managed.path), p.normalize(oldRoot.path))) {
        final nested = Directory(p.join(managed.path, target.desiredFolder));
        try {
          await nested.create(recursive: true);
          parent = nested;
        } on FileSystemException {
          // A folder that cannot be made leaves the take where it is.
        }
      }
    }
    // A take whose folder already carries the wanted name — a finish that was
    // interrupted between the rename and the status write — keeps it, so
    // re-running the step cannot produce a `_2` twin of the same take.
    final wanted = _uniqueDirectory(parent, desired, keep: oldRoot);
    if (!p.equals(p.normalize(wanted.path), p.normalize(oldRoot.path))) {
      try {
        await oldRoot.rename(wanted.path);
        root = wanted;
      } on FileSystemException {
        root = oldRoot;
      }
    }
    // The chat sidecars carry the capture prefix too; give them the same
    // final name as the video so a player finds them beside it.
    for (final extension in _chatExtensions) {
      final old = File(p.join(root.path, '${target.takePrefix}.$extension'));
      if (!old.existsSync()) continue;
      var sidecar = p.join(root.path, '$desired.$extension');
      for (var suffix = 2; File(sidecar).existsSync() && suffix < 1000; suffix++) {
        sidecar = p.join(root.path, '${desired}_$suffix.$extension');
      }
      try {
        await old.rename(sidecar);
      } on FileSystemException {
        // A chat file that cannot move keeps its capture name.
      }
    }
    String? finalFile;
    if (sourceFile != null) {
      var source = p.join(root.path, p.basename(sourceFile));
      if (!File(source).existsSync()) source = sourceFile;
      if (File(source).existsSync()) {
        var candidate = p.join(root.path, '$desired.mp4');
        for (var suffix = 2; File(candidate).existsSync() && suffix < 1000; suffix++) {
          candidate = p.join(root.path, '${desired}_$suffix.mp4');
        }
        try {
          await File(source).rename(candidate);
          finalFile = candidate;
        } on FileSystemException {
          finalFile = File(source).existsSync() ? source : null;
        }
      } else {
        // Nothing to move: a finish interrupted between the file rename and
        // its status write already left the wanted file in place.
        finalFile = _existingNamedFile(root, desired)?.path;
      }
    }
    return (directory: root.path, filePath: finalFile);
  }

  /// The take's wanted single file inside [root], with the suffixes a re-run
  /// may already have used; null when the folder holds none.
  File? _existingNamedFile(Directory root, String desired) {
    for (var suffix = 0; suffix < 8; suffix++) {
      final file = File(p.join(root.path, suffix == 0 ? '$desired.mp4' : '${desired}_$suffix.mp4'));
      if (file.existsSync()) return file;
    }
    return null;
  }
}

/// The engine (one per app; the sessions live inside it).
final recorderEngineProvider = Provider<RecorderEngine>((ref) {
  final engine = RecorderEngine(ref);
  ref
    ..listen(recordingSettingsProvider.select((settings) => settings.recordDanmaku), (previous, next) {
      if (previous != next) engine.setChatRecording(enabled: next);
    })
    ..listen(
      recordingSettingsProvider.select(
        (settings) => (enabled: settings.cacheLimitEnabled, limit: settings.cacheLimitMb),
      ),
      (previous, next) {
        if (next.enabled) engine.trimCacheQuietly();
      },
    )
    ..onDispose(() => unawaited(engine.dispose()));
  return engine;
});
