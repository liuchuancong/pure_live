import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:io' show Directory, File, FileSystemEntity, FileSystemException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show
        DanmakuBlockList,
        DanmakuMessageGate,
        LiveDanmakuProvider,
        LiveDanmakuSession,
        LiveMessage,
        LiveMessageType,
        LivePlayLine,
        LiveRoom;
import 'package:media_core/media_core.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/recorder/data/recording_repository.dart';
import 'package:pure_live/features/recorder/data/recording_settings.dart';
import 'package:pure_live/features/recorder/data/recording_task.dart';
import 'package:pure_live/features/recorder/engine/recording_chat_writer.dart';
import 'package:pure_live/features/shield/shield.dart';

/// How often a running session's byte count is written to its task.
const Duration _kProgressWrite = Duration(seconds: 10);

/// How often recorded chat reaches the XML file.
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
    required this.room,
    required this.danmaku,
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
  final String root;
  final String take;

  /// When this take's video began; chat entries are timed from here.
  late DateTime videoStartedAt;

  RecordChatWriter? chat;
  bool chatOpening = false;
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
  Timer? _cacheTrimTimer;
  Future<int>? _cacheTrim;

  /// Whether the task behind [taskId] is being captured right now.
  bool isRecording(String taskId) => _sessions.containsKey(taskId);

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
    if (_sessions.length >= settings.maxTasks) {
      return 'too many recordings (${_sessions.length}/${settings.maxTasks})';
    }
    // Trim completed takes before the new one lands, so the cap accounts for
    // the recording about to start and never touches an active session.
    if (settings.cacheLimitEnabled) await enforceCacheLimit();
    final directory = await _outputDirectory(settings.saveDir);
    final take = _takeName(task);
    final root = p.join(directory, take);
    final repo = _ref.read(recordingRepositoryProvider).value;
    if (repo == null) return 'the recordings store is not open';
    await repo.save(task.copyWith(state: RecordingTaskState.stopped, startedAt: DateTime.now().toUtc()));

    final backend = FfmpegRecordingBackend(
      outputDirectory: root,
      diskSpace: FfmpegDiskSpace.probe,
      urlRefresher: refreshUrl == null ? null : (source) async => await refreshUrl() ?? source.value,
      config: FfmpegRecordConfig(
        filePrefix: take,
        includeTimestampPrefix: false,
        // Every tunable the settings surface edits reaches FFmpeg here; a
        // setting that did not would be a switch with no effect.
        segmentTime: settings.segmentSeconds,
        rwTimeout: settings.readTimeoutSeconds,
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
      room: room,
      danmaku: danmaku,
    );
    _sessions[task.id] = session;

    try {
      await manager.start(
        // The title stays off the source: the backend names files after it
        // when it is set, and the naming template is the one the viewer
        // chose — the rendered prefix carries both, title included. The
        // line's headers ride along: most platforms answer 403 without
        // their referer.
        source: RecordingSource(
          type: RecordingSourceType.network,
          value: line.url,
          id: task.id,
          headers: line.headers.toMap(),
        ),
      );
    } on Object catch (error) {
      await session.quiet();
      _sessions.remove(task.id);
      unawaited(manager.dispose());
      await repo.setEnded(task.id, RecordingTaskState.failed, errorText: _errorOf(error));
      return 'cannot start: ${_errorOf(error)}';
    }

    await repo.setRunning(task.id);
    session
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

  /// Creates the take's XML file once; the switch read per message lets a
  /// recording already running pick the file up when it is turned on.
  Future<void> _ensureChatFile(_LiveRecording session) async {
    if (session.chat != null || session.chatOpening || session._quieted) return;
    session.chatOpening = true;
    try {
      final writer = await RecordChatWriter.open(
        File(p.join(session.root, '${session.take}.xml')),
        startedAt: session.videoStartedAt,
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
    if (session._quieted || message.type != LiveMessageType.chat) return;
    if (!_ref.read(recordingSettingsProvider).recordDanmaku) return;
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
  Future<String?> stop(String taskId) async {
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
      errorText: result.error == null ? '' : _errorOf(result.error!),
    );
    return null;
  }

  /// Ends every session the engine still holds (app shutdown).
  Future<void> dispose() async {
    _cacheTrimTimer?.cancel();
    _cacheTrimTimer = null;
    for (final taskId in _sessions.keys.toList()) {
      await stop(taskId);
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
      errorText: state.error == null ? '' : _errorOf(state.error!),
    );
  }

  /// The size cap: a recording that reached it is ended by the engine and
  /// saved whole — the reference's behaviour of closing a take rather
  /// than piling files forever.
  Future<void> _writeProgress(String taskId) async {
    final session = _sessions[taskId];
    if (session == null || session._settling) return;
    final bytes = session.backend.state.bytesWritten;
    if (bytes != session._persistedBytes) {
      session._persistedBytes = bytes;
      final repo = _ref.read(recordingRepositoryProvider).value;
      await repo?.setProgress(taskId, bytes);
    }
    if (session.capBytes > 0 && bytes >= session.capBytes) await stop(taskId);
  }

  Future<void> _persist(
    _LiveRecording session, {
    required bool success,
    required int bytes,
    required String errorText,
  }) async {
    await _endAs(session, failed: !success, errorText: errorText, bytes: bytes);
  }

  Future<void> _endAs(_LiveRecording session, {required bool failed, required String errorText, int? bytes}) async {
    _sessions.remove(session.task.id);
    unawaited(session.manager.dispose());
    final repo = _ref.read(recordingRepositoryProvider).value;
    final directory = session.backend.activeDirectory ?? '';
    await repo?.setEnded(
      session.task.id,
      failed ? RecordingTaskState.failed : RecordingTaskState.stopped,
      filePath: directory.isEmpty ? null : directory,
      bytes: bytes,
      errorText: errorText,
    );
    // The finished take is no longer protected: apply the cap at once
    // instead of waiting for the next recording or the minute.
    if (_ref.read(recordingSettingsProvider).cacheLimitEnabled) trimCacheQuietly();
    if (_sessions.isEmpty) {
      _cacheTrimTimer?.cancel();
      _cacheTrimTimer = null;
    }
  }

  void _ensureCacheTrimTimer() {
    _cacheTrimTimer ??= Timer.periodic(_kCacheTrimPeriod, (_) {
      if (_ref.read(recordingSettingsProvider).cacheLimitEnabled) trimCacheQuietly();
    });
  }

  /// Applies the cap without surfacing a failure: a locked file is retried by
  /// the next start, tick or setting change.
  void trimCacheQuietly() {
    unawaited(enforceCacheLimit().then<void>((_) {}, onError: (Object _) {}));
  }

  /// Where recordings land: the viewer's chosen directory, or the app's
  /// own support area when the row is empty. A configured path that cannot
  /// be created falls back to the default rather than failing the take.
  Future<String> _outputDirectory(String saveDir) async => (await _managedRoot(saveDir)).path;

  /// The folder this app owns for recordings. A chosen parent directory gets
  /// a `PureLiveRecords` child with an ownership marker, exactly the
  /// reference's rule: clearing or trimming never touches the user's other
  /// files in a broad folder such as Downloads. An empty setting uses the
  /// app-support `recordings` folder.
  Future<Directory> _managedRoot(String saveDir) async {
    final trimmed = saveDir.trim();
    final Directory root;
    if (trimmed.isEmpty) {
      final support = await getApplicationSupportDirectory();
      root = Directory(p.join(support.path, 'recordings'));
    } else {
      root = Directory(p.join(trimmed, 'PureLiveRecords'));
    }
    await root.create(recursive: true);
    final marker = File(p.join(root.path, _kRecordMarker));
    if (!marker.existsSync()) {
      await marker.writeAsString('Pure Live managed recording directory.\n', flush: true);
    }
    return root;
  }

  /// The roots of takes still being written; cache work skips them.
  Iterable<String> get _activeRoots => _sessions.values.map((session) => p.normalize(session.root));

  bool _isActive(String path) {
    final normalized = p.normalize(path);
    return _activeRoots.any((root) => p.equals(root, normalized) || p.isWithin(root, normalized));
  }

  int _folderBytes(Directory folder) {
    var total = 0;
    try {
      for (final entity in folder.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || p.basename(entity.path) == _kRecordMarker) continue;
        try {
          total += entity.lengthSync();
        } on FileSystemException {
          // A segment rotating mid-walk is simply not counted.
        }
      }
    } on FileSystemException {
      // A folder that vanished is empty.
    }
    return total;
  }

  /// Whether the shared task store says another engine is recording. That
  /// engine's take lives in the same managed folder but is not in this
  /// process's `_sessions`, so cache work must stand down rather than risk
  /// deleting it.
  bool get _hasForeignRecording => _ref
      .read(recordingTasksProvider)
      .tasks
      .any((task) => task.state == RecordingTaskState.recording && !_sessions.containsKey(task.id));

  /// The managed folder's bytes, active takes included.
  Future<int> cacheBytes() async {
    final root = await _managedRoot(_ref.read(recordingSettingsProvider).saveDir);
    return _folderBytes(root);
  }

  /// Deletes every finished managed file and empty folder; active recordings
  /// and the ownership marker stay. Answers the bytes left.
  Future<int> clearCache() async {
    final root = await _managedRoot(_ref.read(recordingSettingsProvider).saveDir);
    if (_hasForeignRecording) return _folderBytes(root);
    final List<FileSystemEntity> entities;
    try {
      entities = root.listSync(recursive: true, followLinks: false);
    } on FileSystemException {
      return _folderBytes(root);
    }
    for (final entity in entities.whereType<File>()) {
      if (p.basename(entity.path) == _kRecordMarker || _isActive(entity.path)) continue;
      try {
        entity.deleteSync();
      } on FileSystemException {
        // A file rotating or locked keeps its share; the next clear retries.
      }
    }
    final directories = entities.whereType<Directory>().toList()
      ..sort((left, right) => right.path.length.compareTo(left.path.length));
    for (final directory in directories) {
      if (_isActive(directory.path)) continue;
      try {
        if (directory.listSync(followLinks: false).isEmpty) directory.deleteSync();
      } on FileSystemException {
        // Non-empty or in use.
      }
    }
    return _folderBytes(root);
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
    final root = await _managedRoot(settings.saveDir);
    var total = _folderBytes(root);
    if (!settings.cacheLimitEnabled || _hasForeignRecording) return total;
    final limit = settings.cacheLimitMb * 1024 * 1024;
    if (total <= limit) return total;
    final entries = <({File file, int size, DateTime modified})>[];
    try {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || p.basename(entity.path) == _kRecordMarker) continue;
        if (_isActive(entity.path)) continue;
        try {
          final stat = entity.statSync();
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
        entry.file.deleteSync();
        total -= entry.size;
      } on FileSystemException {
        // Locked; the next oldest may still fit.
      }
    }
    return total;
  }

  /// The take's directory name: the naming template rendered with the
  /// room's facts, plus a timestamp — two takes of one room must not
  /// name themselves the same, and the timestamp is what the journal and
  /// a browse both read as "this run".
  String _takeName(RecordingTask task) {
    final now = DateTime.now();
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
        (settings) => (enabled: settings.cacheLimitEnabled, limit: settings.cacheLimitMb, saveDir: settings.saveDir),
      ),
      (previous, next) {
        if (next.enabled) engine.trimCacheQuietly();
      },
    )
    ..onDispose(() => unawaited(engine.dispose()));
  return engine;
});
