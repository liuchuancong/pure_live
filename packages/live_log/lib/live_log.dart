/// Application logging facade.
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

export 'src/log/live_log.dart';
export 'src/model/model.dart';
export 'src/pipeline/pipeline.dart';
export 'src/sinks/sinks.dart';
