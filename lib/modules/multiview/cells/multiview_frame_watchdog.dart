import 'dart:async';

import 'package:flutter/foundation.dart';

/// Watches presented frames, not a native player's `playing` flag. A hidden
/// route gets a fresh grace interval when it becomes visible again.
final class MultiviewFrameWatchdog {
  MultiviewFrameWatchdog({
    required this.revision,
    required this.isEligible,
    required this.onStall,
    this.timeout = const Duration(seconds: 10),
    this.hiddenPoll = const Duration(seconds: 1),
    this.elapsed,
  }) : assert(timeout > Duration.zero),
       assert(hiddenPoll > Duration.zero);

  final ValueListenable<int> revision;
  final bool Function() isEligible;
  final VoidCallback onStall;
  final Duration timeout;
  final Duration hiddenPoll;

  /// Optional monotonic clock for deterministic timer tests.
  final Duration Function()? elapsed;

  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  Duration? _deadline;
  int? _lastRevision;
  bool _hidden = false;
  bool _started = false;
  bool _disposed = false;
  Duration get _now => elapsed?.call() ?? _clock.elapsed;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _lastRevision = revision.value;
    _clock.start();
    revision.addListener(_onFrame);
  }

  void _onFrame() {
    if (_disposed || revision.value == _lastRevision) return;
    _lastRevision = revision.value;
    _hidden = !isEligible();
    _deadline = _now + timeout;
    // A high-FPS stream only moves the deadline; it never allocates a timer
    // for every presented frame.
    _timer ??= Timer(_hidden ? hiddenPoll : timeout, _check);
  }

  void _check() {
    _timer = null;
    if (_disposed || _deadline == null) return;
    if (!isEligible()) {
      _hidden = true;
      _timer = Timer(hiddenPoll, _check);
      return;
    }
    if (_hidden) {
      _hidden = false;
      _deadline = _now + timeout;
      _timer = Timer(timeout, _check);
      return;
    }
    final remaining = _deadline! - _now;
    if (remaining > Duration.zero) {
      _timer = Timer(remaining, _check);
      return;
    }
    dispose();
    onStall();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    if (_started) revision.removeListener(_onFrame);
    _clock.stop();
  }
}
