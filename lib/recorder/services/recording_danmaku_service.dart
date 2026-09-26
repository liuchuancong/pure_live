import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/record_status.dart';

/// A live chat connection owned by one recording task.
class RecordingDanmakuConnection {
  const RecordingDanmakuConnection({required this.stop});

  final Future<void> Function() stop;
}

typedef RecordingDanmakuConnector = Future<RecordingDanmakuConnection?> Function(
  LiveRecordTask task,
  void Function(LiveMessage message) onMessage,
);

/// Appends one recording attempt's chat to a Bilibili-format danmaku XML file
/// (`<d p="time,mode,size,color,unix,pool,user,row">text</d>`), which
/// DanmakuFactory, PotPlayer and the biliup/blrec toolchain read.
class RecordingDanmakuWriter {
  RecordingDanmakuWriter._(this.file, this._sink, this.startedAt);

  final File file;
  final IOSink _sink;

  /// Wall-clock start of the attempt; also the time base of its video file.
  final DateTime startedAt;
  var _closed = false;
  var _count = 0;

  int get count => _count;

  static RecordingDanmakuWriter open(File file, {required DateTime startedAt}) {
    final sink = file.openWrite();
    sink.write('<?xml version="1.0" encoding="UTF-8"?>\n<i>\n<chatserver>pure_live</chatserver>\n');
    return RecordingDanmakuWriter._(file, sink, startedAt);
  }

  void add(LiveMessage message, {required DateTime receivedAt}) {
    if (_closed) return;
    final text = escape(message.message);
    if (text.isEmpty) return;
    final offset = receivedAt.difference(startedAt).inMilliseconds / 1000.0;
    final seconds = offset < 0 ? 0.0 : offset;
    final color = (message.color.r << 16) | (message.color.g << 8) | message.color.b;
    final user = (message.userId.isNotEmpty ? message.userId : message.userName).hashCode.toUnsigned(32);
    final unix = (message.sentAt ?? receivedAt).millisecondsSinceEpoch ~/ 1000;
    _sink.write(
      '<d p="${seconds.toStringAsFixed(3)},1,25,$color,$unix,0,${user.toRadixString(16)},0" '
      'user="${escape(message.userName)}">$text</d>\n',
    );
    _count++;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _sink.write('</i>\n');
    await _sink.flush();
    await _sink.close();
  }

  /// XML-escapes text and drops characters XML 1.0 cannot carry.
  static String escape(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final allowed =
          rune == 0x9 ||
          rune == 0xA ||
          rune == 0xD ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD) ||
          rune >= 0x10000;
      if (!allowed) continue;
      switch (rune) {
        case 0x26:
          buffer.write('&amp;');
        case 0x3C:
          buffer.write('&lt;');
        case 0x3E:
          buffer.write('&gt;');
        case 0x22:
          buffer.write('&quot;');
        case 0x27:
          buffer.write('&apos;');
        default:
          buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().trim();
  }
}

class _TaskDanmaku {
  RecordingDanmakuConnection? connection;
  bool connecting = false;
  DateTime? lastConnectFailure;
  RecordingDanmakuWriter? writer;
  String? writerKey;
  bool disposed = false;
  final seenIds = <String>{};
  final seenOrder = Queue<String>();
}

/// Opt-in recording of live chat next to each recorded attempt.
///
/// Observes recorder task snapshots only; it never participates in stream
/// resolution, FFmpeg or finalization, so a chat failure cannot affect video.
/// Each FFmpeg attempt produces `<prefix>.mp4`; its chat goes to
/// `<prefix>.xml` with times relative to the attempt start ([LiveRecordTask]
/// derives the prefix from that same instant).
class RecordingDanmakuService {
  RecordingDanmakuService({
    required this.enabled,
    required this.connect,
    DateTime Function()? now,
    this.retryDelay = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now;

  final bool Function() enabled;
  final RecordingDanmakuConnector connect;
  final DateTime Function() _now;
  final Duration retryDelay;
  final _tasks = <String, _TaskDanmaku>{};
  var _disposed = false;

  static const _connectedStatuses = {RecordStatus.preparing, RecordStatus.running, RecordStatus.reconnecting};

  /// Current output file of a task, for tests and diagnostics.
  File? fileFor(String taskId) => _tasks[taskId]?.writer?.file;

  void sync(Iterable<LiveRecordTask> tasks) {
    if (_disposed) return;
    final live = <String>{};
    final wanted = enabled();
    for (final task in tasks) {
      live.add(task.taskId);
      if (!wanted || !_connectedStatuses.contains(task.status)) {
        unawaited(_release(task.taskId));
        continue;
      }
      final state = _tasks.putIfAbsent(task.taskId, _TaskDanmaku.new);
      _ensureConnection(task, state);
      _syncWriter(task, state);
    }
    for (final taskId in _tasks.keys.where((id) => !live.contains(id)).toList()) {
      unawaited(_release(taskId));
    }
  }

  void _ensureConnection(LiveRecordTask task, _TaskDanmaku state) {
    if (state.connection != null || state.connecting) return;
    final failedAt = state.lastConnectFailure;
    if (failedAt != null && _now().difference(failedAt) < retryDelay) return;
    state.connecting = true;
    unawaited(() async {
      RecordingDanmakuConnection? connection;
      try {
        connection = await connect(task, (message) => _onMessage(state, message));
      } catch (_) {
        connection = null;
      }
      state.connecting = false;
      if (state.disposed || _disposed) {
        await connection?.stop().catchError((Object _) {});
        return;
      }
      if (connection == null) {
        state.lastConnectFailure = _now();
      } else {
        state.connection = connection;
      }
    }());
  }

  void _syncWriter(LiveRecordTask task, _TaskDanmaku state) {
    final directory = task.outputDir?.trim() ?? '';
    if (task.status != RecordStatus.running || directory.isEmpty) {
      // Reconnecting/preparing: the previous attempt's video has ended.
      unawaited(_closeWriter(state));
      return;
    }
    final prefix = task.recordingFilePrefix;
    final key = '$directory\u0000$prefix';
    if (state.writerKey == key) return;
    unawaited(_closeWriter(state));
    try {
      state.writer = RecordingDanmakuWriter.open(File(p.join(directory, '$prefix.xml')), startedAt: task.createTime);
      state.writerKey = key;
    } catch (_) {
      state.writer = null;
      state.writerKey = key; // Do not retry a failing path on every update.
    }
  }

  void _onMessage(_TaskDanmaku state, LiveMessage message) {
    final writer = state.writer;
    if (state.disposed || writer == null || message.type != LiveMessageType.chat) return;
    // Engines may replay recent chat after a WebSocket reconnect.
    final id = message.messageId;
    if (id.isNotEmpty) {
      if (!state.seenIds.add(id)) return;
      state.seenOrder.add(id);
      if (state.seenOrder.length > 2048) state.seenIds.remove(state.seenOrder.removeFirst());
    }
    try {
      writer.add(message, receivedAt: _now());
    } catch (_) {
      // A failing chat file must never affect the recording.
    }
  }

  Future<void> _closeWriter(_TaskDanmaku state) async {
    final writer = state.writer;
    state.writer = null;
    state.writerKey = null;
    await writer?.close().catchError((Object _) {});
  }

  Future<void> _release(String taskId) async {
    final state = _tasks.remove(taskId);
    if (state == null) return;
    state.disposed = true;
    // Await the close so dispose() returns with the XML terminated and the
    // file handle released (Windows keeps open files locked).
    await _closeWriter(state);
    final connection = state.connection;
    state.connection = null;
    await connection?.stop().catchError((Object _) {});
  }

  Future<void> dispose() async {
    _disposed = true;
    await Future.wait(_tasks.keys.toList().map(_release));
  }
}
