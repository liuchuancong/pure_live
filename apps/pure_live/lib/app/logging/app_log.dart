import 'dart:async' show StreamController, Timer, unawaited;
import 'dart:io' show Directory, File;

import 'package:live_log/live_log.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;

/// The size one log file reaches before it rotates, unless the setting says
/// otherwise.
const int kDefaultAppLogFileMaxBytes = 4 * 1024 * 1024;

/// The stored keys the log settings page owns.
const String _levelKey = 'log.level';
const String _fileKey = 'log.file';
const String _fileMaxBytesKey = 'log.fileMaxBytes';
const String _filesKeptKey = 'log.filesKept';
const String _fileNameKey = 'log.fileName';
const String _formatKey = 'log.exportFormat';

/// The base name a log file starts with: the rotating files are
/// `PureLive.log`, `PureLive.1.log`, … unless the viewer names them.
const String kDefaultAppLogBaseName = 'PureLive';

/// The longest name the setting takes; a file name, not a sentence.
const int kAppLogBaseNameMaxLength = 40;

/// The file type a saved copy takes: plain text as `.txt` or as the
/// conventional `.log`, or one JSON object per line as `.jsonl`.
enum LogExportFormat {
  /// Plain text under a `.txt` name: reads in any editor.
  txt,

  /// Plain text under a `.log` name: the same bytes, the extension a log
  /// viewer expects.
  log,

  /// One JSON object per line: greppable and machine-readable, for a report
  /// that gets parsed.
  jsonLines;

  /// The file extension a copy takes.
  String get extension => switch (this) {
    LogExportFormat.txt => 'txt',
    LogExportFormat.log => 'log',
    LogExportFormat.jsonLines => 'jsonl',
  };

  /// Whether the copy encodes records as JSON lines.
  bool get isJsonLines => this == LogExportFormat.jsonLines;
}

/// The app's one log tree: a console line, the in-memory ring the log page
/// reads, and (once storage opens) a rotating file. Records are sanitised
/// by live_log before any sink sees them.
/// The console's records: every record this process wrote, no count limit.
final MemorySink appLogMemory = MemorySink(capacity: 0);
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
Directory? _directory;
int _fileMaxBytes = kDefaultAppLogFileMaxBytes;
int _fileMaxFiles = 0;
bool _fileEnabled = true;
String _baseName = kDefaultAppLogBaseName;
LogExportFormat _exportFormat = LogExportFormat.txt;

/// The file sink's current switch, so a refresh that changes nothing does not
/// reopen the file.
String? _sinkPath;
int _sinkMaxBytes = 0;
int _sinkMaxFiles = -1;
String _sinkBaseName = '';

/// The folder the rotating files are written to: the storage layout's logs
/// folder with the viewer's own choice already laid over it, which the boot
/// installs and the log settings keep in step. Null before the boot runs.
Directory? get appLogDirectory => _directory;

/// The folder the file sink writes into right now.
String? get appLogDirectoryPath => _directory?.path;

/// The size a log file reaches before it rotates.
int get appLogFileMaxBytes => _fileMaxBytes;

/// How many rotating files are kept, the live one included; zero keeps every
/// file forever.
int get appLogFilesKept => _fileMaxFiles;

/// The base name the rotating files carry, without the `.log` suffix.
String get appLogBaseName => _baseName;

/// How a saved copy encodes the records.
LogExportFormat get appLogExportFormat => _exportFormat;

/// Today's folder name under the log directory, so the file list reads as
/// days rather than one flat run.
String get appLogDay => _dayStamp(DateTime.now());

String _dayStamp(DateTime day) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

/// Today's folder under [root].
Directory _dayDirectory(Directory root) => Directory(p.join(root.path, appLogDay));

/// A viewer-typed name as a safe file name: path separators and the
/// characters Windows refuses are dropped, and an empty answer falls back to
/// the default rather than naming a file ''.
String normalizeAppLogBaseName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\/:*?"<>|]'), '').trim();
  final cut = cleaned.length > kAppLogBaseNameMaxLength
      ? cleaned.substring(0, kAppLogBaseNameMaxLength).trimRight()
      : cleaned;
  return cut.isEmpty ? kDefaultAppLogBaseName : cut;
}

/// Attaches the rotating file sink and applies the stored log preferences.
/// [directory] is the logs folder the storage layout answers. Called once
/// after storage opens; safe to call again.
void initAppLog({required Directory directory}) {
  _directory ??= directory;
  syncAppLogFromStore();
}

/// Moves the rotating files to [directory] — the storage page's answer after
/// the viewer picked or reset the logs folder — and reopens the sink there.
void applyAppLogDirectory(Directory directory) {
  if (_directory?.path == directory.path) return;
  _directory = directory;
  _attachFileSink();
}

/// Re-reads every stored log preference and applies it to this process's
/// tree, so a write from another window or a restored backup lands here on
/// the settings refresh.
void syncAppLogFromStore() {
  _fileMaxBytes = _readInt(_fileMaxBytesKey) ?? kDefaultAppLogFileMaxBytes;
  _fileMaxFiles = _readInt(_filesKeptKey) ?? 0;
  _baseName = normalizeAppLogBaseName(_readString(_fileNameKey) ?? kDefaultAppLogBaseName);
  _exportFormat = LogExportFormat.values.asNameMap()[_readString(_formatKey) ?? ''] ?? LogExportFormat.txt;
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

/// Renames the rotating files: the live file is closed and the next line
/// opens under the new name, in the same day's folder.
void setAppLogBaseName(String name) {
  final next = normalizeAppLogBaseName(name);
  if (next == _baseName) return;
  _baseName = next;
  unawaitedStore(() => StoragePrefs.setString(_fileNameKey, next));
  _attachFileSink();
}

/// Chooses how a saved copy encodes the records.
void setAppLogExportFormat(LogExportFormat format) {
  if (format == _exportFormat) return;
  _exportFormat = format;
  unawaitedStore(() => StoragePrefs.setString(_formatKey, format.name));
}

/// Sets how many rotating files are kept (zero keeps all) and rebuilds the
/// sink, since the trim rule is fixed when the sink opens.
void setAppLogFilesKept(int files) {
  if (files == _fileMaxFiles) return;
  _fileMaxFiles = files.clamp(0, 100);
  unawaitedStore(() => StoragePrefs.setInt(_filesKeptKey, _fileMaxFiles));
  _attachFileSink();
}

/// Drops every in-memory record (the file keeps what it wrote).
void clearAppLog() {
  appLogMemory.clear();
  _memorySink.notifyNow();
}

/// The in-memory records as text, for the clipboard/export path.
String exportAppLog() => appLogMemory.exportText();

/// Writes the in-memory records beside the log files — the viewer's own copy
/// of what the console shows, named so it sorts after the rotating files.
///
/// The ring is the source: a file that is switched off still exports, and a
/// file that is on is not disturbed.
Future<File> saveAppLogCopy() async {
  final directory = _directory;
  if (directory == null) throw StateError('the log directory is not open yet');
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  // The base name and the whole stamp, so a copy stays identifiable after it
  // is moved out of its day folder.
  final stamp = '${now.year}-${two(now.month)}-${two(now.day)}-${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
  final file = File(p.join(_dayDirectory(directory).path, '$_baseName-$stamp.${_exportFormat.extension}'));
  final body = _exportFormat.isJsonLines ? appLogMemory.exportJsonLines() : exportAppLog();
  await file.parent.create(recursive: true);
  await file.writeAsString(body, flush: true);
  return file;
}

/// The live log file's path, once the file sink is attached.
String? get appLogFile {
  final directory = _directory;
  return directory == null ? null : p.join(directory.path, appLogDay, '$_baseName.log');
}

/// Replaces the file sink so it follows the current folder and limits; does
/// nothing while they already match. The old handle is closed on the sink
/// queue, never in the caller's frame.
void _attachFileSink() {
  final directory = _directory;
  if (directory == null) return;
  // One folder per day: the files read as days rather than one flat list.
  // A day a long-running session crosses is picked up the next time the sink
  // is rebuilt (a settings change, the copy action or the next launch).
  final dayDirectory = _dayDirectory(directory);
  final current = _fileSink;
  if (current != null &&
      _sinkPath == dayDirectory.path &&
      _sinkMaxBytes == _fileMaxBytes &&
      _sinkMaxFiles == _fileMaxFiles &&
      _sinkBaseName == _baseName) {
    current.enabled = _fileEnabled;
    return;
  }
  if (current != null) {
    _sinks.sinks.remove(current);
    unawaited(current.close());
  }
  final sink = _SwitchableSink(
    FileSink(dayDirectory, baseName: _baseName, maxFileBytes: _fileMaxBytes, maxFiles: _fileMaxFiles),
    enabled: _fileEnabled,
  );
  _fileSink = sink;
  _sinkPath = dayDirectory.path;
  _sinkMaxBytes = _fileMaxBytes;
  _sinkMaxFiles = _fileMaxFiles;
  _sinkBaseName = _baseName;
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

String? _readString(String key) {
  try {
    return StoragePrefs.getString(key);
  } on Object {
    return null;
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
