/// Logging facade for Pure Live.
///
/// One `LiveLog` tree per process: pick a root with sinks and a level
/// policy, hand out category views with `LiveLog.forCategory`, and emit
/// through the levelled helpers (`debug`, `info`, …). Records are
/// sanitised (signed URL parameters, cookies, authorization headers)
/// before any sink sees them, and a failing sink never breaks the caller.
///
/// The core is Flutter-free: file locations and framework error hooks are
/// wired by the app shell, not here.
library;

export 'src/context.dart';
export 'src/dispatcher.dart';
export 'src/error_reporter.dart';
export 'src/filter.dart';
export 'src/formatter.dart';
export 'src/level.dart';
export 'src/live_log.dart';
export 'src/record.dart';
export 'src/sanitizer.dart';
export 'src/sink.dart';
export 'src/sinks/console_sink.dart';
export 'src/sinks/file_sink.dart';
export 'src/sinks/memory_sink.dart';
