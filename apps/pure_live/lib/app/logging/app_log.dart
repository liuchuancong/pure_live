import 'dart:async' show StreamController, Timer, unawaited;
import 'dart:io' show Directory;

import 'package:live_log/live_log.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

/// The app's one log tree: a console line, the in-memory ring the log page
/// reads, and (once storage opens) a rotating file. Records are sanitised
/// by live_log before any sink sees them.
final MemorySink appLogMemory = MemorySink(capacity: 1000);
final _NotifyingSink _memorySink = _NotifyingSink(appLogMemory);
final FanOutSink _sinks = FanOutSink([const LoggerConsoleSink(), _memorySink]);
final LiveLog _root = LiveLog.root(sinks: [_sinks]);

/// The process log tree.
LiveLog get appLog => _root;

/// Emits after records land in [appLogMemory], coalesced so a burst of
/// network logs does not rebuild the log page once per line.
Stream<void> get appLogChanges => _memorySink.changes;

/// The current tree minimum level.
LogLevel appLogLevel = LogLevel.debug;

_SwitchableSink? _fileSink;
Directory? _logDirectory;

/// The directory the rotating files live in, once [initAppLog] has run.
Directory? get appLogDirectory => _logDirectory;

/// Attaches the rotating file sink and applies the stored level/file
/// preferences. Called once after storage opens; safe to call again.
void initAppLog({required Directory directory}) {
  _logDirectory = directory;
  final level = _readLevel() ?? LogLevel.debug;
  appLogLevel = level;
  // Request lines are emitted at debug by live_net; keep them available
  // for the log page and the file even when the tree's default is info.
  _root
    ..setMinLevel(level)
    ..setMinLevel(LogLevel.debug, category: 'network');
  if (_fileSink != null) {
    return;
  }
  final sink = _SwitchableSink(
    FileSink(directory, baseName: 'pure_live', maxFileBytes: 4 * 1024 * 1024, maxFiles: 4),
    enabled: _readFileEnabled() ?? true,
  );
  _fileSink = sink;
  _sinks.sinks.add(sink);
}

/// The file sink's current switch.
bool get appLogFileEnabled => _fileSink?.enabled ?? false;

/// Changes the tree level and stores it.
void setAppLogLevel(LogLevel level) {
  appLogLevel = level;
  _root.setMinLevel(level);
  unawaitedStore(() => StoragePrefs.setString('log.level', level.name));
}

/// Turns the file sink on or off and stores the choice.
void setAppLogFileEnabled({required bool enabled}) {
  _fileSink?.enabled = enabled;
  unawaitedStore(() => StoragePrefs.setBool('log.file', enabled));
}

/// Drops every in-memory record (the file keeps what it wrote).
void clearAppLog() {
  appLogMemory.clear();
  _memorySink.notifyNow();
}

/// The in-memory records as text, for the clipboard/export path.
String exportAppLog() => appLogMemory.exportText();

/// The live log file's path, when the file sink is attached.
String? get appLogFile => _logDirectory == null ? null : p.join(_logDirectory!.path, 'pure_live.log');

/// Runs a preference write without making the caller await it; a closed
/// store loses the choice rather than failing the action.
void unawaitedStore(Future<void> Function() write) {
  unawaited(_guard(write));
}

Future<void> _guard(Future<void> Function() write) async {
  try {
    await write();
  } on Object {
    // A preference; a closed store loses it.
  }
}

LogLevel? _readLevel() {
  try {
    return LogLevel.values.asNameMap()[StoragePrefs.getString('log.level')];
  } on Object {
    return null;
  }
}

bool? _readFileEnabled() {
  try {
    return StoragePrefs.getBool('log.file');
  } on Object {
    return null;
  }
}

/// Fans a record into the ring buffer, then tells listeners after a short
/// quiet period.
final class _NotifyingSink implements LogSink {
  _NotifyingSink(this._memory);

  final MemorySink _memory;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Timer? _pending;

  Stream<void> get changes => _changes.stream;

  @override
  void write(LogRecord record) {
    _memory.write(record);
    _pending ??= Timer(const Duration(milliseconds: 200), () {
      _pending = null;
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  void notifyNow() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> close() async {
    _pending?.cancel();
    _pending = null;
    await _memory.close();
    await _changes.close();
  }
}

/// A sink whose file child can be switched off without losing its handle.
final class _SwitchableSink implements LogSink {
  _SwitchableSink(this._inner, {required this.enabled});

  final LogSink _inner;
  bool enabled;

  @override
  void write(LogRecord record) {
    if (enabled) _inner.write(record);
  }

  @override
  Future<void> close() => _inner.close();
}
