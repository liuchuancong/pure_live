import 'package:live_log/src/level.dart';
import 'package:live_log/src/record.dart';
import 'package:live_log/src/sink.dart';

/// Level policy for a `LiveLog` tree: one default minimum level plus
/// per-category overrides.
///
/// An override on a category path governs that path and every descendant
/// (`player` at [LogLevel.debug] also quiets or opens `player.mpv`). The
/// most specific override wins; unmatched categories fall back to
/// [minLevel].
final class LogFilter {
  /// A filter with [minLevel] as the default and [categoryMinLevels] as
  /// exact-path overrides.
  new({this.minLevel = LogLevel.info, Map<String, LogLevel> categoryMinLevels = const {}})
    : categoryMinLevels = Map.of(categoryMinLevels);

  /// Default minimum level applied where no category override matches.
  LogLevel minLevel;

  /// Exact-path overrides keyed by category.
  final Map<String, LogLevel> categoryMinLevels;

  /// Sets the default minimum level, or the override for [category] when
  /// given (exact path, e.g. `live_net.socket`).
  void setMinLevel(LogLevel level, {String? category}) {
    if (category == null || category.isEmpty) {
      minLevel = level;
      return;
    }
    categoryMinLevels[category] = level;
  }

  /// Whether a record at [level] from [category] passes the policy.
  bool isLoggable(LogLevel level, String category) {
    var path = category;
    while (path.isNotEmpty) {
      final override = categoryMinLevels[path];
      if (override != null) {
        return level.isAtLeast(override);
      }
      final dot = path.lastIndexOf('.');
      if (dot <= 0) {
        break;
      }
      path = path.substring(0, dot);
    }
    return level.isAtLeast(minLevel);
  }
}

/// Wraps a [LogSink] with its own minimum level, so one tree can feed a
/// verbose console and a warnings-only file at the same time.
final class LevelFilterSink implements LogSink {
  /// Forwards records at [minLevel] or above to [inner].
  new(this.inner, {this.minLevel = LogLevel.trace});

  /// The wrapped sink.
  final LogSink inner;

  /// Minimum level this sink accepts, regardless of the tree policy.
  LogLevel minLevel;

  @override
  void write(LogRecord record) {
    if (!record.level.isAtLeast(minLevel)) {
      return;
    }
    inner.write(record);
  }

  @override
  Future<void> close() => inner.close();
}
