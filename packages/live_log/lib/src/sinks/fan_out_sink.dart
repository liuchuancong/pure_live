import 'package:live_log/src/record.dart';
import 'package:live_log/src/sink.dart';

/// Fans one record out to several sinks.
///
/// The composition sink: a process that wants the console *and* a file
/// *and* the in-memory ring buffer a bug report attaches writes
/// `FanOutSink([console, file, memory])` once, instead of replacing sinks as
/// the app learns more about its environment. Each child keeps its own
/// behaviour — a sink binding's level, a file sink's rotation — because the
/// fan-out hands the record over untouched.
///
/// Fault isolation is the dispatcher's job, and this sink does not duplicate
/// it: a throwing child is the dispatcher's problem to contain, and swallowing
/// here would hide which sink failed. [close] closes the children in order and
/// waits for all of them, so a shutdown that awaits this sink really has
/// flushed every destination.
final class FanOutSink implements LogSink {
  /// A sink writing to every sink in [sinks].
  new(this.sinks);

  /// The destinations, in write order.
  final List<LogSink> sinks;

  bool _closed = false;

  @override
  void write(LogRecord record) {
    if (_closed) {
      return;
    }
    for (final sink in sinks) {
      sink.write(record);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    // Every child closes even when one throws: a failed file sink must not
    // keep the console sink (or the socket, or the buffer) from closing.
    for (final sink in sinks) {
      try {
        await sink.close();
      } on Object {
        // The child reported its own failure when it happened; a close
        // failure has nowhere useful to go and must not abort the others.
      }
    }
  }
}
