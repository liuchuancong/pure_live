import 'dart:async';

import 'package:live_log/src/level.dart';
import 'package:live_log/src/record.dart';
import 'package:live_log/src/sink.dart';

/// A [LogSink] together with its own minimum level.
///
/// Wrap a sink in this (instead of passing it bare) when one tree should
/// feed sinks at different verbosity — e.g. a trace-level console next to
/// a warnings-only file.
final class SinkBinding {
  /// Binds [sink] to records at [minLevel] or above.
  const new(this.sink, {this.minLevel = LogLevel.trace});

  /// The wrapped sink.
  final LogSink sink;

  /// Minimum level this binding forwards, regardless of the tree policy.
  final LogLevel minLevel;
}

/// Fan-out point between the `LiveLog` tree and its sinks.
///
/// Responsibilities: apply per-binding level filtering, guarantee fault
/// isolation — a throwing sink neither breaks the caller nor the other
/// sinks, and its failure is never re-logged (which would recurse) — and
/// support hot-swapping a sink while the tree keeps emitting.
final class LogDispatcher {
  /// A dispatcher over [sinks]; elements may be bare [LogSink]s or
  /// [SinkBinding]s.
  new({required List<Object> sinks})
    : _bindings = [
        for (final sink in sinks)
          if (sink is SinkBinding) sink else SinkBinding(sink as LogSink),
      ];

  final List<SinkBinding> _bindings;

  /// Delivers [record] to every binding whose level accepts it.
  void dispatch(LogRecord record) {
    for (final binding in _bindings) {
      if (!record.level.isAtLeast(binding.minLevel)) {
        continue;
      }
      try {
        binding.sink.write(record);
      } on Object {
        // Fault isolation: never propagate, never re-log.
      }
    }
  }

  /// Atomically replaces [oldSink] (matched by identity) with [newSink].
  ///
  /// The new binding keeps the old one's minimum level unless [minLevel]
  /// says otherwise. Records routed after the swap go to [newSink]; the
  /// old sink is closed in the background, draining whatever it still has
  /// queued, so nothing already handed to it is lost. Returns whether
  /// [oldSink] was part of this dispatcher.
  bool replaceSink(LogSink oldSink, LogSink newSink, {LogLevel? minLevel}) {
    final index = _bindings.indexWhere((binding) => identical(binding.sink, oldSink));
    if (index < 0) {
      return false;
    }
    final previous = _bindings[index];
    _bindings[index] = SinkBinding(newSink, minLevel: minLevel ?? previous.minLevel);
    unawaited(_closeQuietly(previous.sink));
    return true;
  }

  /// Closes every sink, tolerating individual failures.
  Future<void> close() async {
    for (final binding in _bindings) {
      await _closeQuietly(binding.sink);
    }
  }

  static Future<void> _closeQuietly(LogSink sink) async {
    try {
      await sink.close();
    } on Object {
      // Close failures must not mask the original shutdown reason.
    }
  }
}
