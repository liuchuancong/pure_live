import 'package:live_log/src/model/record.dart';

/// A destination for sanitised [LogRecord]s.
///
/// Sinks are handed records that already passed the tree-level filter and
/// redaction; a `LogDispatcher` additionally applies per-sink levels and
/// fault isolation. Implementations must not throw from [write]; heavy work
/// belongs on an internal queue.
abstract interface class LogSink {
  /// Consumes one record. Must be cheap and must not throw.
  void write(LogRecord record);

  /// Releases resources. No further records arrive after this returns.
  Future<void> close();
}
