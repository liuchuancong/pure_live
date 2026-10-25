import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:io' show Directory;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LivePlayLine;
import 'package:media_core/media_core.dart';
import 'package:media_core_recording_ffmpeg/media_core_recording_ffmpeg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;

import 'package:pure_live/app/providers/user_notification_providers.dart' show requestUserNotificationPermission;
import 'package:pure_live/features/recorder/recording_repository.dart';
import 'package:pure_live/features/recorder/recording_settings.dart';
import 'package:pure_live/features/recorder/recording_task.dart';

/// How often a running session's byte count is written to its task.
const Duration _kProgressWrite = Duration(seconds: 10);

/// The failure text a task keeps: one paragraph, never a stack.
String _errorOf(Object error) {
  final line = error.toString().split('\n').first.trim();
  return line.length > 240 ? '${line.substring(0, 240)}…' : line;
}

/// A recording the engine holds open: its manager, the backend that answers
/// for the files, the task it belongs to, and the small machinery that
/// writes progress and guards the size cap.
final class _LiveRecording {
  _LiveRecording({required this.manager, required this.backend, required this.task, required this.capBytes});

  final RecordingManager manager;
  final FfmpegRecordingBackend backend;
  RecordingTask task;
  final int capBytes;

  StreamSubscription<RecordingState>? _states;
  Timer? _ticker;
  int _persistedBytes = 0;
  bool _settling = false;

  Future<void> quiet() async {
    _ticker?.cancel();
    _ticker = null;
    await _states?.cancel();
    _states = null;
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

  /// Whether the task behind [taskId] is being captured right now.
  bool isRecording(String taskId) => _sessions.containsKey(taskId);

  /// Starts capturing the room [task] names at [line]'s address.
  ///
  /// [refreshUrl] may re-mint the address when the stream drops and the
  /// old one has expired; null keeps re-opening the same address. The
  /// line's headers ride the recording — most platforms answer 403
  /// without their referer. Returns null when the capture began, and the
  /// engine's own words when it did not.
  Future<String?> start(RecordingTask task, LivePlayLine line, {Future<String?> Function()? refreshUrl}) async {
    if (_sessions.containsKey(task.id)) return 'already recording';
    // The permission prompt belongs to the action that needs it.
    unawaited(requestUserNotificationPermission());
    final settings = _ref.read(recordingSettingsProvider);
    if (_sessions.length >= settings.maxTasks) {
      return 'too many recordings (${_sessions.length}/${settings.maxTasks})';
    }
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
      .._states = backend.onStateChanged.listen((state) => unawaited(_onState(task.id, state)))
      .._ticker = Timer.periodic(_kProgressWrite, (_) => unawaited(_writeProgress(task.id)));
    return null;
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
  }

  /// Where recordings land: the viewer's chosen directory, or the app's
  /// own support area when the row is empty. A configured path that cannot
  /// be created falls back to the default rather than failing the take.
  Future<String> _outputDirectory(String saveDir) async {
    final trimmed = saveDir.trim();
    if (trimmed.isNotEmpty) {
      try {
        await Directory(trimmed).create(recursive: true);
        return trimmed;
      } on Object {
        // Fall through to the app's own directory below.
      }
    }
    final support = await getApplicationSupportDirectory();
    final root = p.join(support.path, 'recordings');
    await Directory(root).create(recursive: true);
    return root;
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
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});
