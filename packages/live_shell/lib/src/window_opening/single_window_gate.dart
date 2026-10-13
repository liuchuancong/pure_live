import 'dart:async';

/// Serialises "make sure the main window exists".
///
/// The trigger set is large and they arrive together: start-up, the tray icon,
/// the macOS Dock click, a forwarded second instance, a protocol link, a
/// notification click. Creating the window is asynchronous — persisted state is
/// read, a plugin round-trips, the first frame is awaited — so the naive form
///
/// ```dart
/// if (window == null) await createWindow();
/// ```
///
/// lets every trigger past the null check before the first of them finishes, and
/// each then builds a window: two or three real windows, all but the last
/// unreachable through the field they overwrote, and no error anywhere to
/// notice it by. This gate is the fix, and the reason it is a type rather than a
/// local variable is that the bug returns the moment a second call site
/// re-implements the check.
final class SingleWindowGate {
  /// A gate that calls [create] when no window is present.
  ///
  /// [create] must set the shell's window field itself; the gate only ensures
  /// it runs once. [present] reports whether a live window exists now.
  new({required this.create, required this.present});

  /// Builds the window, showing it if `forceShow` was requested.
  final Future<void> Function({required bool forceShow}) create;

  /// Whether a live window exists.
  final bool Function() present;

  Future<void>? _running;

  /// Whether a show was asked for while the window was being created.
  bool _pendingForceShow = false;

  /// Whether a creation is in flight.
  bool get isCreating => _running != null;

  /// Ensures a window exists, joining any creation already in flight.
  ///
  /// [forceShow] means "the viewer asked to see it": if a silent creation is
  /// already running (start-up with the window deliberately not shown, or a
  /// background launch), the request is remembered and the in-flight creation
  /// consumes it, instead of either being ignored or starting a second window.
  Future<void> ensure({bool forceShow = false}) {
    if (present()) {
      return Future<void>.value();
    }
    final running = _running;
    if (running != null) {
      if (forceShow) {
        _pendingForceShow = true;
      }
      return running;
    }
    if (forceShow) {
      _pendingForceShow = true;
    }
    final attempt = Future<void>(() async {
      // Read and clear the merged intent here, not in the caller: with several
      // triggers collapsed into one creation, the last one to arrive is as
      // entitled to it as the first.
      final shouldShow = _pendingForceShow;
      _pendingForceShow = false;
      await create(forceShow: shouldShow);
    });
    _running = attempt;
    return attempt.whenComplete(() => _running = null);
  }
}
