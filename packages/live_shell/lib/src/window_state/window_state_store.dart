import 'dart:async';

import 'package:live_shell/src/window_geometry/window_geometry.dart';

/// Remembers where the window was, and hands it back validated.
///
/// Three rules, each learned the expensive way:
///
/// * **Never persist a maximised frame as the restore size.** While maximised,
///   the window manager reports the outer frame it just fitted to the display —
///   which is not the size the viewer dragged the window to. Store it as the
///   restore size and the next start opens at full screen with the "restore"
///   button sizing the window to the whole monitor. This class keeps the last
///   non-maximised frame and pairs it with the maximised flag instead.
/// * **Debounce the writes.** `resized` fires many times a second while a
///   border is being dragged, and each one would otherwise hit the disk.
/// * **Validate on the way back.** Frames are only meaningful while the display
///   they belong to exists; after a monitor was unplugged the remembered frame
///   can sit past the edge of everything, and a window the app swears is open
///   but nobody can see is worse than one that opens at a default place.
///   [restore] runs the frame through [keepOnScreen] before offering it.
final class WindowStateStore {
  /// A store that persists through [save] and reads back through [load].
  new({required this.save, required this.load, this.debounce = const Duration(milliseconds: 500)});

  /// Writes one record.
  final Future<void> Function(WindowGeometry record) save;

  /// Reads the last record, null the first time.
  final Future<WindowGeometry?> Function() load;

  /// How long a quiet period is before a change is written.
  final Duration debounce;

  Timer? _timer;
  WindowGeometry? _pending;
  WindowGeometry? _lastSaved;
  WindowGeometry? _restoreFrame;
  bool _enabled = true;
  bool _saving = false;

  /// Stops recording: used when the window is destroyed, because a teardown
  /// resizes the surface on the way out and that frame is not something to
  /// remember. Anything still queued is dropped rather than written.
  void pause() {
    _enabled = false;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  /// Starts recording again after a [pause], once a window exists to describe.
  void resume() => _enabled = true;

  /// Records the window's state as it now is.
  ///
  /// Cheap enough to call from every `resized`, `moved` and `maximised` event.
  void note(WindowGeometry geometry) {
    if (!_enabled) {
      return;
    }
    if (!geometry.maximized) {
      // While not maximised the frame is the viewer's own choice, so it is the
      // restore frame — nothing to reconcile.
      _restoreFrame = geometry;
    }
    final restore = _restoreFrame;
    final record = geometry.maximized && restore != null
        ? restore.copyWith(maximized: true, displayId: geometry.displayId)
        : geometry;
    if (record == _lastSaved) {
      return;
    }
    _pending = record;
    _timer?.cancel();
    _timer = Timer(debounce, _flushPending);
  }

  Future<void> _flushPending() async {
    final pending = _pending;
    _pending = null;
    if (pending == null || _saving) {
      return;
    }
    // Serialised on purpose: a write overlapping the next one can land them out
    // of order, and the older frame wins.
    _saving = true;
    try {
      await save(pending);
      _lastSaved = pending;
    } finally {
      _saving = false;
      if (_pending != null) {
        _timer = Timer(debounce, _flushPending);
      }
    }
  }

  /// Writes whatever is unsaved, immediately. Every quit path calls this: a
  /// debounced write lost to process exit is a window that opens in the wrong
  /// place tomorrow, and the viewer will drag it back into place all over again.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    await _flushPending();
  }

  /// The remembered state, corrected against the displays that exist now.
  Future<WindowGeometry?> restore(List<DisplayFrame> displays) async {
    final record = await load();
    if (record == null) {
      return null;
    }
    _restoreFrame = record.maximized ? null : record;
    _lastSaved = record;
    return keepOnScreen(record, displays);
  }
}
