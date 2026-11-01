import 'dart:io' show FileSystemException;

import 'package:live_lan_sync/src/config/config.dart' show LanSyncLoggingConfig;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError;
import 'package:live_log/live_log.dart' show LiveLog, LogLevel;

/// The subsystems one engine logs under. Each is a category below the
/// host's view: a host handing in `appLog.forCategory('lan_sync')` gets
/// `lan_sync.sync`, `lan_sync.sync.favorites`, and so on.
enum LanSyncLogArea {
  /// Device discovery and network changes.
  discovery,

  /// Pairing ceremonies and trust management.
  pairing,

  /// The change log, batch exchanges and conflict settlement.
  sync,

  /// File transfers.
  transfer,

  /// The HTTP server and client.
  transport,
}

/// The engine's entry into the host's log tree (spec §4.1 observability).
///
/// The engine never creates sinks and never reaches a global logger: the
/// host builds one `LanSyncLogger` over a view of its own `live_log` tree
/// and hands it to the components it composes. Without one, every
/// component logs nowhere.
///
/// ```dart
/// final logger = LanSyncLogger(appLog.forCategory('lan_sync'), config: config.logging);
/// final engine = SyncEngine(..., logger: logger);
/// ```
final class LanSyncLogger {
  /// A logger writing into [view], under [config]'s level and payload
  /// policy.
  new(LiveLog view, {LanSyncLoggingConfig config = const LanSyncLoggingConfig()})
    : _view = view..setMinLevel(config.level == LogLevel.off ? LogLevel.off : LogLevel.trace),
      _floor = config.level,
      logPayloads = config.logPayloads;

  new _silent() : _view = LiveLog.root(minLevel: LogLevel.off), _floor = LogLevel.off, logPayloads = false;

  /// The logger of components given none: a tree whose filter passes
  /// nothing, so no record is even built.
  static final LanSyncLogger silent = LanSyncLogger._silent();

  final LiveLog _view;
  final LogLevel _floor;

  /// Whether change payloads may appear in debug records.
  final bool logPayloads;

  /// The log of one subsystem.
  LanSyncLog area(LanSyncLogArea area) => LanSyncLog._(_view.forCategory(area.name), _floor);
}

/// One subsystem's log: live_log's levelled calls behind the engine's own
/// level floor, with redaction the engine owes on top of live_log's.
///
/// What never goes in, by construction: pairing secrets, signatures,
/// nonces, the six-digit comparison code, local file paths, and payloads
/// unless the host opted in. Failures are logged by code and category, not
/// by their debug context, which may carry paths.
final class LanSyncLog {
  new _(this._view, this._floor);

  final LiveLog _view;
  final LogLevel _floor;

  /// Whether a record at [level] would be built and kept — test this
  /// before assembling expensive fields.
  bool isEnabled(LogLevel level) => level.isAtLeast(_floor) && _view.isLoggable(level);

  /// The log one level down, e.g. per scope: `lan_sync.sync.favorites`.
  LanSyncLog child(String name) => LanSyncLog._(_view.forCategory(name), _floor);

  /// Developer detail: per batch, per chunk, per request.
  void debug(String message, {Map<String, Object?> fields = const {}}) => _emit(LogLevel.debug, message, fields);

  /// Lifecycle: started, finished, paired, committed.
  void info(String message, {Map<String, Object?> fields = const {}}) => _emit(LogLevel.info, message, fields);

  /// Recovered or refused: retries, rejections, possible tampering.
  void warning(String message, {Map<String, Object?> fields = const {}}) => _emit(LogLevel.warning, message, fields);

  /// A failure that needs attention, with the scrubbed error.
  void error(String message, {Map<String, Object?> fields = const {}, Object? error, StackTrace? stackTrace}) {
    if (!isEnabled(LogLevel.error)) return;
    _view.error(message, fields: fields, error: scrub(error), stackTrace: stackTrace);
  }

  /// Logs [failure] at [level] by its stable facts — code, category,
  /// retryability, device — never its debug context.
  void failure(
    String message,
    LanSyncError failure, {
    LogLevel level = LogLevel.warning,
    Map<String, Object?> fields = const {},
  }) => _emit(level, message, {
    'code': failure.code,
    'category': failure.category.name,
    'retryable': failure.retryable,
    if (failure.deviceId != null) 'device': failure.deviceId,
    ...fields,
  });

  void _emit(LogLevel level, String message, Map<String, Object?> fields) {
    if (!isEnabled(level)) return;
    _view.log(level, message, fields: fields);
  }

  /// [error] without anything a log must not carry: a file-system error
  /// loses its path.
  static Object? scrub(Object? error) => switch (error) {
    final FileSystemException fs => FileSystemException(fs.message, '', fs.osError),
    _ => error,
  };

  /// A fingerprint short enough to read and long enough to tell apart:
  /// `sha256:` plus twelve hex digits.
  static String shortFingerprint(String fingerprint) =>
      fingerprint.length > 19 ? '${fingerprint.substring(0, 19)}…' : fingerprint;
}
