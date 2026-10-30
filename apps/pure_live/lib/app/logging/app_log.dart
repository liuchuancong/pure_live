import 'dart:async' show StreamController, Timer, unawaited;
import 'dart:io' show Directory;

import 'package:live_log/live_log.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

/// The size one log file reaches before it rotates, unless the setting says
/// otherwise.
const int kDefaultAppLogFileMaxBytes = 4 * 1024 * 1024;

/// How many log files the sink keeps, the live one included.
const int kDefaultAppLogFileMaxFiles = 4;

/// How many records the memory ring holds for the log page.
const int kDefaultAppLogMemoryCapacity = 1000;

/// The stored keys the log settings page owns.
const String _levelKey = 'log.level';
const String _fileKey = 'log.file';
const String _fileMaxBytesKey = 'log.fileMaxBytes';
const String _fileMaxFilesKey = 'log.fileMaxFiles';
const String _memoryCapacityKey = 'log.memoryCapacity';
const String _directoryKey = 'log.directory';

/// The app's one log tree: a console line, the in-memory ring the log page
/// reads, and (once storage opens) a rotating file. Records are sanitised
/// by live_log before any sink sees them.
final MemorySink appLogMemory = MemorySink(capacity: kDefaultAppLogMemoryCapacity);
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
Directory? _defaultDirectory;
String _customDirectory = '';
int _fileMaxBytes = kDefaultAppLogFileMaxBytes;
int _fileMaxFiles = kDefaultAppLogFileMaxFiles;
bool _fileEnabled = true;

/// What the attached sink was built with, so a refresh that changes nothing
/// does not reopen the file.
String? _sinkPath;
int _sinkMaxBytes = 0;
int _sinkMaxFiles = 0;

/// The folder the rotating files are written to: the viewer's own choice
/// when they picked one, else the storage layer's logs folder. Null until
/// [initAppLog] runs.
Directory? get _logDirectory {
  if (_customDirectory.isNotEmpty) return Directory(_customDirectory);
  return _defaultDirectory;
}

/// The folder the rotating files live in, once [initAppLog] has run.
Directory? get appLogDirectory => _logDirectory;

/// The storage layer's own logs folder, before any custom choice.
String? get appLogDefaultDirectory => _defaultDirectory?.path;

/// The folder the file sink writes into right now.
String? get appLogDirectoryPath => _logDirectory?.path;

/// Whether a folder other than the default is in use.
bool get appLogDirectoryCustom => _customDirectory.isNotEmpty;

/// The size a log file reaches before it rotates.
int get appLogFileMaxBytes => _fileMaxBytes;

/// How many log files are kept.
int get appLogFileMaxFiles => _fileMaxFiles;

/// How many records the memory ring holds.
int get appLogMemoryCapacity => appLogMemory.capacity;

/// Attaches the rotating file sink and applies the stored log preferences.
/// Called once after storage opens; safe to call again.
void initAppLog({required Directory directory}) {
  _defaultDirectory ??= directory;
  syncAppLogFromStore();
}

/// Re-reads every stored log preference and applies it to this process's
/// tree, so a write from another window or a restored backup lands here on
/// the settings refresh.
void syncAppLogFromStore() {
  _customDirectory = _readString(_directoryKey) ?? '';
  _fileMaxBytes = _readInt(_fileMaxBytesKey) ?? kDefaultAppLogFileMaxBytes;
  _fileMaxFiles = _readInt(_fileMaxFilesKey) ?? kDefaultAppLogFileMaxFiles;
  appLogMemory.capacity = _readInt(_memoryCapacityKey) ?? kDefaultAppLogMemoryCapacity;
  _fileEnabled = _readBool(_fileKey) ?? true;
  final level = _readLevel() ?? LogLevel.debug;
  appLogLevel = level;
  // Request lines are emitted at debug by live_net; keep them available
  // for the log page and the file even when the tree's default is info.
  _root
    ..setMinLevel(level)
    ..setMinLevel(LogLevel.debug, category: 'network');
  _attachFileSink();
}

/// The file sink's current switch.
bool get appLogFileEnabled => _fileEnabled;

/// Changes the tree level and stores it.
void setAppLogLevel(LogLevel level) {
  appLogLevel = level;
  _root.setMinLevel(level);
  unawaitedStore(() => StoragePrefs.setString(_levelKey, level.name));
}

/// Turns the file sink on or off and stores the choice.
void setAppLogFileEnabled({required bool enabled}) {
  _fileEnabled = enabled;
  _fileSink?.enabled = enabled;
  unawaitedStore(() => StoragePrefs.setBool(_fileKey, enabled));
}

/// Sets the size a log file reaches before it rotates and rebuilds the sink;
/// the live file is closed, and the new limit applies from the next line.
void setAppLogFileMaxBytes(int bytes) {
  if (bytes == _fileMaxBytes) return;
  _fileMaxBytes = bytes;
  unawaitedStore(() => StoragePrefs.setInt(_fileMaxBytesKey, bytes));
  _attachFileSink();
}

/// Sets how many log files are kept and rebuilds the sink.
void setAppLogFileMaxFiles(int files) {
  if (files == _fileMaxFiles) return;
  _fileMaxFiles = files;
  unawaitedStore(() => StoragePrefs.setInt(_fileMaxFilesKey, files));
  _attachFileSink();
}

/// Resizes the memory ring the log page reads; the oldest lines go first.
void setAppLogMemoryCapacity(int capacity) {
  if (capacity == appLogMemory.capacity) return;
  appLogMemory.capacity = capacity;
  _memorySink.notifyNow();
  unawaitedStore(() => StoragePrefs.setInt(_memoryCapacityKey, capacity));
}

/// Writes the log folder to [path] (already proven writable by the caller)
/// and reopens the file sink there.
void setAppLogDirectory(String path) {
  final normalized = path.trim();
  if (normalized == _customDirectory) return;
  _customDirectory = normalized;
  unawaitedStore(() => StoragePrefs.setString(_directoryKey, normalized));
  _attachFileSink();
}

/// Returns the log folder to the storage layer's own logs directory.
void resetAppLogDirectory() => setAppLogDirectory('');

/// Drops every in-memory record (the file keeps what it wrote).
void clearAppLog() {
  appLogMemory.clear();
  _memorySink.notifyNow();
}

/// The in-memory records as text, for the clipboard/export path.
String exportAppLog() => appLogMemory.exportText();

/// The live log file's path, once the file sink is attached.
String? get appLogFile {
  final directory = _logDirectory;
  return directory == null ? null : p.join(directory.path, 'pure_live.log');
}

/// Replaces the file sink so it follows the current folder and limits; does
/// nothing while they already match. The old handle is closed on the sink
/// queue, never in the caller's frame.
void _attachFileSink() {
  final directory = _logDirectory;
  if (directory == null) return;
  final current = _fileSink;
  if (current != null &&
      _sinkPath == directory.path &&
      _sinkMaxBytes == _fileMaxBytes &&
      _sinkMaxFiles == _fileMaxFiles) {
    current.enabled = _fileEnabled;
    return;
  }
  if (current != null) {
    _sinks.sinks.remove(current);
    unawaited(current.close());
  }
  final sink = _SwitchableSink(
    FileSink(directory, baseName: 'pure_live', maxFileBytes: _fileMaxBytes, maxFiles: _fileMaxFiles),
    enabled: _fileEnabled,
  );
  _fileSink = sink;
  _sinkPath = directory.path;
  _sinkMaxBytes = _fileMaxBytes;
  _sinkMaxFiles = _fileMaxFiles;
  _sinks.sinks.add(sink);
}

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
    return LogLevel.values.asNameMap()[StoragePrefs.getString(_levelKey)];
  } on Object {
    return null;
  }
}

bool? _readBool(String key) {
  try {
    return StoragePrefs.getBool(key);
  } on Object {
    return null;
  }
}

int? _readInt(String key) {
  try {
    return StoragePrefs.getInt(key);
  } on Object {
    return null;
  }
}

String? _readString(String key) {
  try {
    return StoragePrefs.getString(key);
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
