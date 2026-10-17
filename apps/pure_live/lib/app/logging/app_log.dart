import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:live_log/live_log.dart';
import 'package:live_uikit/live_uikit.dart';

/// The log policy this build ships.
///
/// Debug builds trace the whole tree into the stdout sink, so a desktop
/// launch without an IDE still shows everything; release builds keep
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
    _attachable = FanOutSink([MemorySink()]);
    root = LiveLog.root(
      sinks: [if (kDebugMode) const StdoutConsoleSink(), _attachable],
      minLevel: _settings.minLevel,
      categoryMinLevels: _settings.categoryMinLevels,
    );
  }

  final LogSettings _settings;
  late final FanOutSink _attachable;

  /// The tree every category view branches from.
  late final LiveLog root;

  /// A view under [name] — `forCategory('storage')` on this, then
  /// `forCategory('paths')` on that, yields the `storage.paths` category.
  LiveLog forCategory(String name) => root.forCategory(name);

  /// The sink `AppTheme` reports UI-runtime facts through: which effect this
  /// device could not afford, for which language and which control. A language
  /// with no adapter is no longer a line here — it is a fault the resolver
  /// raises, because there is nothing left to fall back to.
  LiveUiDiagnosticSink get uiSink =>
      (diagnostic) => forCategory('ui').info(
        'ui diagnostic',
        fields: {
          'code': diagnostic.code.name,
          'language': diagnostic.language.name,
          if (diagnostic.control case final control?) 'control': control.name,
          if (diagnostic.surface case final surface?) 'surface': surface.name,
        },
      );

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
