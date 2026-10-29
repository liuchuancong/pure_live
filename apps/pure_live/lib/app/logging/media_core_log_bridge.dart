import 'package:live_log/live_log.dart';
import 'package:media_core_logging/media_core_logging.dart' as media;
import 'package:pure_live/app/logging/app_log.dart' show appLog;

/// Bridges the media core's log hub into the app's [appLog] tree.
///
/// `media_core_logging` is opt-in with pluggable sinks: installing the bridge
/// turns the hub on at debug and replaces its sink with one that re-emits
/// every record under a `media_core.<module>` category, so playback
/// decisions ride the same console line, ring buffer, file and log page as
/// the rest of the app — and the tree's per-category level can narrow one
/// module without silencing the rest. The hub's own developer-log console is
/// dropped with the swap; forwarding it too would print every record twice.
///
/// The hub's gate is the core's own: records below its level never reach the
/// bridge, so turning the app's tree up to trace does not surface the core's
/// trace lines until the hub's level rises with it.
void installMediaCoreLogBridge() {
  media.MediaCoreLog.configure(level: media.LogLevel.debug, sink: _forward);
}

final Map<media.LogCategory, LiveLog> _views = {};

void _forward(media.PlayerLogRecord record) {
  (_views[record.category] ??= appLog.forCategory('media_core.${record.category.name}')).log(
    _levelOf(record.level),
    record.message,
    fields: record.fields,
    error: record.error,
    stackTrace: record.stackTrace,
  );
}

LogLevel _levelOf(media.LogLevel level) => switch (level) {
  media.LogLevel.trace => LogLevel.trace,
  media.LogLevel.debug => LogLevel.debug,
  media.LogLevel.info => LogLevel.info,
  media.LogLevel.warning => LogLevel.warning,
  media.LogLevel.error => LogLevel.error,
  media.LogLevel.critical => LogLevel.fatal,
  // Not a record level; the arm only completes the switch.
  media.LogLevel.nothing => LogLevel.off,
};
