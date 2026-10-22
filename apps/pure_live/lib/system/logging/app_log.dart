import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:live_log/live_log.dart';

/// The log policy this build ships.
///
  /// Debug builds trace the whole tree into the pretty console sink, so a
  /// desktop launch without an IDE still shows everything; release builds keep
/// regular operations and above. [categoryMinLevels] quiets one loud
/// category without touching the rest of the tree; a settings page adjusts
/// the live policy later through `LiveLog.setMinLevel`, never by
/// rebuilding the tree.
final class LogSettings {
  /// A log policy.
  const new({required this.minLevel, this.categoryMinLevels = const {}});

  /// The policy for the build at hand.
  // A factory cannot use the `new` shorthand, so the type name stays.
  // ignore: unnecessary_type_name_in_constructor
  factory LogSettings.forBuild() => const LogSettings(minLevel: kDebugMode ? LogLevel.trace : LogLevel.info);

  /// The tree's default minimum level.
  final LogLevel minLevel;

  /// Exact-path category overrides on top of [minLevel].
  final Map<String, LogLevel> categoryMinLevels;
}

/// The process log: one `LiveLog` tree, assembled here because its sinks
/// depend on facts that arrive in two waves.
///
/// At construction only the console (debug builds) and the in-memory ring
/// exist — the earliest errors must land somewhere before the directory
/// layout is known. Once boot has resolved the data area, [attachFileSink]
/// adds the rotating file sink to the fan-out. The append takes effect on
/// the next record: the dispatcher snapshots the root's sink bindings, but
/// the fan-out re-reads its destination list on every write, which makes it
/// the one live composition point — and the reason this class owns it
/// instead of handing the raw sinks around.
final class AppLog {
  /// The process log for [settings].
  new({LogSettings? settings}) : _settings = settings ?? LogSettings.forBuild() {
    ring = MemorySink();
    _attachable = FanOutSink([ring]);
    root = LiveLog.root(
      sinks: [if (kDebugMode) const LoggerConsoleSink(), _attachable],
      minLevel: _settings.minLevel,
      categoryMinLevels: _settings.categoryMinLevels,
    );
  }

  final LogSettings _settings;
  late final FanOutSink _attachable;

  /// The in-memory ring every record also passes through — the log page's
  /// export reads recent history from here (`query`/`exportJsonLines`).
  late final MemorySink ring;

  /// The tree every category view branches from.
  late final LiveLog root;

  /// A view under [name] — `forCategory('storage')` on this, then
  /// `forCategory('paths')` on that, yields the `storage.paths` category.
  LiveLog forCategory(String name) => root.forCategory(name);

  /// Adds the rotating file sink under [directory].
  ///
  /// Idempotency is the caller's concern — boot calls this once, when the
  /// data area first resolves.
  void attachFileSink(Directory directory) {
    _attachable.sinks.add(FileSink(directory));
  }

  /// Closes every sink; the tree goes quiet. Later emits are no-ops.
  Future<void> close() => root.close();
}

/// Maps a stored log-level id (the log page's preference; '' is "build
/// default") to the tree threshold to apply, null when there is none.
LogLevel? logLevelForStoredId(String levelId) => switch (levelId) {
  'trace' => LogLevel.trace,
  'debug' => LogLevel.debug,
  'info' => LogLevel.info,
  'warning' => LogLevel.warning,
  'error' => LogLevel.error,
  'off' => LogLevel.off,
  _ => null,
};

/// Re-tunes the live tree from the stored preference — start-up replays it,
/// and the log page applies it on every change.
void applyStoredLogLevel(AppLog log, String levelId) {
  final level = logLevelForStoredId(levelId);
  if (level != null) log.root.setMinLevel(level);
}
