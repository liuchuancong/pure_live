import 'package:live_log/src/level.dart';
import 'package:live_log/src/live_log.dart';

/// Turns uncaught errors into log records.
///
/// Conversion only — installing framework handlers
/// (`FlutterError.onError`, `PlatformDispatcher.onError`) is the Flutter
/// integration layer's job, done in the app shell. Call [report] from those
/// hooks; never let the reporter mutate global handlers itself.
abstract final class ErrorReporter {
  /// Logs [error] (and its [stackTrace]) on [log] at [LogLevel.error].
  ///
  /// [message] overrides the default headline; [fields] carry structured
  /// context such as the failing task or isolate name.
  static void report(
    LiveLog log,
    Object error,
    StackTrace? stackTrace, {
    String? message,
    Map<String, Object?> fields = const {},
  }) {
    log.log(LogLevel.error, message ?? 'uncaught error: $error', fields: fields, error: error, stackTrace: stackTrace);
  }
}
