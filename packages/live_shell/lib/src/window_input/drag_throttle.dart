import 'dart:async';

/// Suspends UI work while the window is being dragged, and merges what was
/// skipped into one update when it settles.
///
/// On Windows a window drag runs a modal message loop on the thread that owns
/// the window, so every frame pulled during the drag is a frame the compositor
/// cannot use: a live app pushing bitrate, frame rate, connection state and
/// danmaku at 60 Hz will stutter the drag and force a full re-composite of the
/// whole surface. The answer is not to drop the updates — the viewer would see
/// a frozen number after the drag ends — but to hold the latest value and emit
/// it once the pointer stops moving.
///
/// Two details carry the correctness:
///
/// * Settlement is decided by *the move events stopping for [settle]*, not by a
///   "drag ended" callback, because the end-of-drag notification is unreliable
///   across window managers and especially over remote desktop, where the drag
///   can simply stop producing events.
/// * [dispose] and the window's own teardown must call [reset]: a flag left true
///   by a window destroyed mid-drag silences every later update for the rest of
///   the session, which is invisible in testing and fatal in the field.
final class DragThrottle {
  /// A throttle that calls [onBegin] when a drag starts and [onEnd] when it
  /// settles; both are optional, [onEnd] being the one that matters.
  new({this.settle = const Duration(milliseconds: 120), this.onBegin, this.onEnd});

  /// How long a pause in move events counts as "the drag is over".
  final Duration settle;

  /// Called on the first move event of a drag.
  final void Function()? onBegin;

  /// Called once the drag settles.
  final void Function()? onEnd;

  Timer? _timer;
  bool _dragging = false;
  bool _disposed = false;

  /// Whether a drag is in progress right now.
  bool get isDragging => _dragging;

  /// Whether UI work may run: true when no drag is in flight.
  ///
  /// Ask this at the point of broadcast rather than cancelling timers in every
  /// producer — one predicate, many callers, no way for a new producer to
  /// forget the rule.
  bool get allowsUiWork => !_dragging;

  /// Reports a move event. Cheap enough to call for every one.
  void noteMoved() {
    if (_disposed) {
      return;
    }
    if (!_dragging) {
      _dragging = true;
      onBegin?.call();
    }
    _timer?.cancel();
    _timer = Timer(settle, _settle);
  }

  /// Forces the end of a drag: used when the window is hidden or destroyed, so
  /// the flag cannot be left set by a drag that never got to settle.
  void reset() {
    _timer?.cancel();
    _timer = null;
    if (_dragging) {
      _dragging = false;
      onEnd?.call();
    }
  }

  /// Releases the pending timer; later [noteMoved] calls do nothing.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _dragging = false;
  }

  void _settle() {
    _timer = null;
    if (_disposed || !_dragging) {
      return;
    }
    _dragging = false;
    onEnd?.call();
  }
}

/// Holds one latest value and hands it out when the throttle ends.
///
/// The pairing with [DragThrottle] is what makes "suspend during the drag" read
/// as "the numbers kept up" rather than "the numbers froze": the newest value
/// seen during the suspension is published as soon as it is safe to draw.
final class LatestValueGate<T> {
  /// A gate over a throttle.
  new(this._throttle);

  final DragThrottle _throttle;
  bool _has = false;
  T? _latest;

  /// Replaces the pending value, emitting it at once if no drag is running.
  ///
  /// Returns whether [value] was delivered to [onEmit] immediately, which lets
  /// a caller that counts emissions tell the two paths apart.
  bool offer(T value, void Function(T) onEmit) {
    if (!_throttle.isDragging) {
      onEmit(value);
      return true;
    }
    _latest = value;
    _has = true;
    return false;
  }

  /// Whether a value is being held back.
  bool get hasPending => _has;

  /// Emits the held value, if any. Called from [DragThrottle.onEnd].
  void flush(void Function(T) onEmit) {
    if (!_has) {
      return;
    }
    final value = _latest as T;
    _has = false;
    _latest = null;
    onEmit(value);
  }
}
