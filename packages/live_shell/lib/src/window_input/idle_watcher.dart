import 'dart:async';

/// Reads how long the machine has gone without input.
///
/// A seam rather than a call: Windows answers this from `GetLastInputInfo`,
/// macOS from the session dictionary and Linux from an idle timer or X screen
/// saver, and none of those belong in a package that must be testable without a
/// desktop session. The shell only ever asks "how long has it been".
typedef SystemIdleReader = Future<Duration> Function();

/// Watches the machine for idleness and reports the crossing once.
///
/// What makes this a type instead of a `Timer.periodic` at the call site is the
/// reporting rule: the threshold must be announced **once per idle period**, not
/// every poll. A shell that fires on each tick destroys the interface, then
/// "discovers" it is idle again a minute later and tries to destroy it a second
/// time — the symptom being a window that reappears and vanishes on its own.
///
/// The reading is polled rather than event-driven because there is no portable
/// idle event; that costs granularity, and the cost is documented at
/// [interval] rather than hidden.
final class IdleWatcher {
  /// A watcher reading idleness from [read] every [interval].
  new({
    required this.read,
    required this.threshold,
    this.interval = const Duration(minutes: 1),
    this.onIdle,
    this.onError,
  });

  /// Where the idle duration comes from.
  final SystemIdleReader read;

  /// How much idleness counts.
  final Duration threshold;

  /// How often to ask.
  ///
  /// With polling there is no exact crossing: a one-minute interval means the
  /// report arrives somewhere between [threshold] and threshold plus a minute.
  /// That is the right trade for reclaiming memory — a timer that fires late is
  /// invisible, whereas an event-based idle hook does not exist on all three
  /// platforms — but it is wrong for anything the viewer can perceive, so do
  /// not borrow this to schedule anything user-visible.
  final Duration interval;

  /// Notified when a poll fails, and then retried at the next tick.
  final void Function(Object error, StackTrace stack)? onError;

  /// Called once per idle period, with the measured duration.
  final void Function(Duration idle)? onIdle;

  Timer? _timer;
  bool _reported = false;
  bool _reading = false;

  /// Whether the current idle period has already been reported.
  bool get hasReported => _reported;

  /// Starts polling. Calling it twice is a restart, not a second timer.
  void start() {
    _timer?.cancel();
    _reported = false;
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  /// Stops polling and forgets the latch.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Records that the viewer did something, arming the next crossing to be
  /// reported again.
  ///
  /// Call this from real activity — a window shown, a key pressed, a tray click.
  /// Without it, one reported crossing stays reported for the life of the
  /// process and the interface is never reclaimed again, however long it sits
  /// hidden.
  void noteActivity() => _reported = false;

  /// Releases everything.
  Future<void> dispose() async => stop();

  Future<void> _poll() async {
    // Overlapping reads are avoided rather than locked: the idle query is cheap,
    // but a slow or hung source (a session switch, a locked screen) would
    // otherwise pile up one pending read per tick.
    if (_reading) {
      return;
    }
    _reading = true;
    final Duration idle;
    try {
      idle = await read();
    } on Object catch (error, stack) {
      _reading = false;
      onError?.call(error, stack);
      return;
    }
    _reading = false;
    if (idle < threshold) {
      // Active again: re-arm, so a later idle period is reported on its own.
      _reported = false;
      return;
    }
    if (_reported) {
      return;
    }
    _reported = true;
    onIdle?.call(idle);
  }
}
