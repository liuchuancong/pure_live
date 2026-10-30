import 'dart:io' show Directory, File, FileSystemException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show LogLevel;
import 'package:pure_live/app/logging/app_log.dart';

/// What the log tree is configured to do right now: the minimum level the
/// sinks see, whether a file is written and how it rotates, how many records
/// the memory ring holds, and which folder the files live in.
typedef LogSettings = ({
  LogLevel level,
  bool fileEnabled,
  int fileMaxBytes,
  int fileMaxFiles,
  int memoryCapacity,
  String directory,
  String defaultDirectory,
  bool directoryCustom,
});

/// Owns the log configuration. Every write goes through the app's log tree so
/// the running sinks change with the stored preference, and a refresh (another
/// window, a restored backup) re-reads the store and re-applies it here.
final class LogSettingsController extends Notifier<LogSettings> {
  @override
  LogSettings build() {
    syncAppLogFromStore();
    return _current();
  }

  /// The level the tree records at; lines below it never reach a sink.
  Future<void> setLevel(LogLevel level) async => _apply(() => setAppLogLevel(level));

  /// Turns the rotating file on or off; off keeps only the memory ring.
  Future<void> setFileEnabled({required bool enabled}) async => _apply(() => setAppLogFileEnabled(enabled: enabled));

  /// The size one file reaches before the sink rotates to the next.
  Future<void> setFileMaxBytes(int bytes) async => _apply(() => setAppLogFileMaxBytes(bytes));

  /// How many files the sink keeps, the live one included.
  Future<void> setFileMaxFiles(int files) async => _apply(() => setAppLogFileMaxFiles(files));

  /// How many records the memory ring holds for the log page.
  Future<void> setMemoryCapacity(int capacity) async => _apply(() => setAppLogMemoryCapacity(capacity));

  /// Points the file sink at [path] once it proves it accepts writes; false
  /// means nothing changed and the caller shows the permission hint.
  Future<bool> setDirectory(String path) async {
    final normalized = path.trim();
    if (normalized.isNotEmpty && !await _acceptsWrites(normalized)) return false;
    _apply(() => setAppLogDirectory(normalized));
    return true;
  }

  /// Returns the files to the storage layer's own logs folder.
  Future<void> resetDirectory() async => _apply(resetAppLogDirectory);

  void _apply(void Function() write) {
    write();
    state = _current();
  }

  static LogSettings _current() => (
    level: appLogLevel,
    fileEnabled: appLogFileEnabled,
    fileMaxBytes: appLogFileMaxBytes,
    fileMaxFiles: appLogFileMaxFiles,
    memoryCapacity: appLogMemoryCapacity,
    directory: appLogDirectoryPath ?? '',
    defaultDirectory: appLogDefaultDirectory ?? '',
    directoryCustom: appLogDirectoryCustom,
  );
}

/// The log configuration the settings page edits.
final logSettingsProvider = NotifierProvider<LogSettingsController, LogSettings>(LogSettingsController.new);

/// Proves [path] accepts writes. A folder the app cannot write to would make
/// the file sink degrade silently, so the choice is tested before it is kept.
Future<bool> _acceptsWrites(String path) async {
  try {
    final directory = Directory(path);
    await directory.create(recursive: true);
    final probe = File(directory.uri.resolve('.write_probe').toFilePath());
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}
