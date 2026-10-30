import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show LogLevel;
import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;

/// What the log tree is configured to do right now: the minimum level the
/// sinks see, whether a file is written, how large one file may grow, and
/// which folder the files live in. Neither the console nor the folder keeps a
/// count limit: a record is forgotten only when the process ends, and a file
/// only gives way to the next one at the size limit.
typedef LogSettings = ({LogLevel level, bool fileEnabled, int fileMaxBytes, String directory});

/// Owns the log configuration. Every write goes through the app's log tree so
/// the running sinks change with the stored preference, and a refresh (another
/// window, a restored backup) re-reads the store and re-applies it here.
final class LogSettingsController extends Notifier<LogSettings> {
  @override
  LogSettings build() {
    // The folder is the storage layout's answer with the viewer's own choice
    // laid over it, so the 存储位置 page owns it and a move lands here on the
    // next rebuild — the running sink follows.
    applyAppLogDirectory(ref.watch(appPathsProvider).logs);
    syncAppLogFromStore();
    return _current();
  }

  /// The level the tree records at; lines below it never reach a sink.
  Future<void> setLevel(LogLevel level) async => _apply(() => setAppLogLevel(level));

  /// Turns the rotating file on or off; off keeps only the memory ring.
  Future<void> setFileEnabled({required bool enabled}) async => _apply(() => setAppLogFileEnabled(enabled: enabled));

  /// The size one file reaches before the sink rotates to the next.
  Future<void> setFileMaxBytes(int bytes) async => _apply(() => setAppLogFileMaxBytes(bytes));

  void _apply(void Function() write) {
    write();
    state = _current();
  }

  static LogSettings _current() => (
    level: appLogLevel,
    fileEnabled: appLogFileEnabled,
    fileMaxBytes: appLogFileMaxBytes,
    directory: appLogDirectoryPath ?? '',
  );
}

/// The log configuration the settings page edits.
final logSettingsProvider = NotifierProvider<LogSettingsController, LogSettings>(LogSettingsController.new);
