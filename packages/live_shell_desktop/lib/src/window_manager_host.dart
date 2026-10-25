import 'dart:async';
import 'dart:ui' show Rect;

import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/src/displays.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Used for the one stateless calculation the reader performs over a frame.
const _screenRetrieverDisplays = ScreenRetrieverDisplays();

/// The main window, driven through `window_manager`'s object API.
///
/// The host pins its own window on the engine's first focus event (see
/// [_onEvent]) and addresses every verb and every event through that pin —
/// never through the manager's "current window", which answers the active
/// window of the shared main thread and, once a secondary window takes
/// focus, belongs to *that* window. A host that forgot this answered a
/// clone's close request as its own and quit the whole process.
///
/// The listener is registered on [attach] and removed on [dispose], and that
/// pairing is not ceremony: the manager keeps a strong list, so a shell that
/// rebuilds its window (lightweight mode, a render failure) without removing
/// accumulates one listener per rebuild. Every event then reaches the dead hosts
/// too, and the first symptom is a caption button that toggles twice.
final class WindowManagerHost implements WindowHost {
  /// A host for [role], resolving displays through [readDisplays].
  ///
  /// [verifyOwnWindow] is the identity oracle a multi-window app provides:
  /// given a candidate window id it answers whether that window is *this
  /// engine's own*. With one, the host pins its window on the first focus
  /// event that verifies; a secondary window's focus, arriving while this
  /// engine has not pinned yet, is then rejected instead of mistaken for
  /// the primary — the mistake that made a clone's close quit the whole
  /// process. Without one, the first focus pins unconditionally, which is
  /// correct wherever the engine owns the only window that can take focus.
  new({required this.role, DisplayReader? readDisplays, this.verifyOwnWindow})
    : _readDisplays = readDisplays ?? const ScreenRetrieverDisplays().read {
    _events = StreamController<WindowEvent>.broadcast();
  }

  /// Whether a candidate window id belongs to this engine's own window.
  final Future<bool> Function(int windowId)? verifyOwnWindow;

  /// What this window is for.
  @override
  final WindowRole role;

  final DisplayReader _readDisplays;
  late final StreamController<WindowEvent> _events;

  bool _alive = true;
  bool _attached = false;
  bool _preventClose = false;
  bool _destroying = false;
  wm.ListenerId? _listener;

  /// This engine's own window, pinned on its first focus event; null until
  /// then. Every verb and every event filter goes through the pin — see
  /// [_onEvent] for why the manager's "current window" must not be trusted.
  wm.Window? _self;

  @override
  bool get isAlive => _alive;

  @override
  Stream<WindowEvent> get events => _events.stream;

  /// The window, or null while the native side has not registered one yet —
  /// a gap every read must tolerate, because the first widget frame can be
  /// built before the registration lands. The pinned [_self] answers first;
  /// the manager's current window is only the hot-restart fallback, where
  /// the engine's own window is the focused one and the pin has not landed.
  wm.Window? get _windowOrNull {
    if (_self != null) {
      return _self;
    }
    try {
      return wm.WindowManager.instance.getCurrent();
    } on Object {
      return null;
    }
  }

  /// The current engine's window for a verb. A hot restart can leave the
  /// plugin's registration a moment behind the first boot task, so a missing
  /// window is waited for briefly; a host that truly has none skips the verb
  /// rather than turning a startup race into a failed boot.
  Future<wm.Window?> _windowForVerb() async {
    final existing = _windowOrNull;
    if (existing != null) return existing;
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final window = _windowOrNull;
      if (window != null) return window;
    }
    return null;
  }

  /// Subscribes to the plugin. Calling it again does nothing.
  ///
  /// Guarded here rather than trusted to the manager's listener collection:
  /// a duplicate registration means every event is delivered twice, and the
  /// close policy is not idempotent — two destroys, two quit records, two exits.
  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    _listener = wm.WindowManager.instance.addListener(_onEvent);
  }

  /// Pins [candidate] once the identity oracle accepts it. A rejection —
  /// or an oracle that answered nothing — leaves the host unpinned, and
  /// the next focus event asks again; a wrong pin is the bug this whole
  /// path exists to prevent, so a doubt is never resolved by guessing.
  Future<void> _pinVerified(wm.Window candidate, Future<bool> Function(int windowId) verify) async {
    try {
      if (await verify(candidate.id)) {
        _self = candidate;
      }
    } on Object {
      // The oracle answered nothing; the next focus event asks again.
    }
  }

  /// The manager's global event stream, narrowed to this window and folded
  /// into `live_shell`'s vocabulary.
  ///
  /// Two words go quiet on this platform: docking has no native event, and an
  /// unmaximise arrives as the same restore event an unminimise does, so the
  /// consumer sees one `restored` for both — which is what the close policy
  /// and the geometry store actually act on.
  void _onEvent(wm.WindowEvent event) {
    // The event's own window, resolved within this process: a foreign
    // application's foreground change resolves to nothing here and is
    // dropped, because the manager's lookup only ever finds windows of the
    // process it runs in.
    final window = wm.WindowManager.instance.get(event.windowId);
    if (window == null) {
      return;
    }
    // The pin: the first focused window of this process is this engine's
    // own — no secondary window exists yet, and a foreign one never
    // resolved above. From here on the host answers only for the window it
    // pinned; a secondary window's close request, arriving while that
    // secondary window happens to be the active one, must be ignored
    // rather than answered with the primary's quit.
    if (_self == null && event is wm.WindowFocusedEvent) {
      final candidate = window;
      final verify = verifyOwnWindow;
      if (verify == null) {
        _self = candidate;
      } else {
        unawaited(_pinVerified(candidate, verify));
      }
    }
    if (_self == null || event.windowId != _self!.id) {
      return; // another engine's window, or not pinned yet.
    }
    switch (event) {
      case wm.WindowCloseRequestedEvent(:final request):
        // The request fires for every close, whatever raised it — the caption,
        // a taskbar command, `alt+f4`. Preventing close means cancelling it
        // here and letting the shell decide, except when the shell itself is
        // destroying the window: its own quit must land.
        if (_preventClose && !_destroying) {
          request.cancel();
          _emit(WindowEvent.closeRequested);
        }
      case wm.WindowFocusedEvent():
        _emit(WindowEvent.focused);
      case wm.WindowBlurredEvent():
        _emit(WindowEvent.blurred);
      case wm.WindowMinimizedEvent():
        _emit(WindowEvent.minimised);
      case wm.WindowMaximizedEvent():
        _emit(WindowEvent.maximised);
      case wm.WindowRestoredEvent():
        _emit(WindowEvent.restored);
      case wm.WindowMovedEvent():
        _emit(WindowEvent.moved);
      case wm.WindowResizedEvent():
        _emit(WindowEvent.resized);
      case wm.WindowEnteredFullScreenEvent():
        _emit(WindowEvent.enteredFullScreen);
      case wm.WindowExitedFullScreenEvent():
        _emit(WindowEvent.leftFullScreen);
      case wm.WindowClosedEvent():
        _alive = false;
        _emit(WindowEvent.closed);
      default:
        break;
    }
  }

  @override
  Future<void> show({bool inactive = false}) async {
    final window = await _windowForVerb();
    if (window == null) return;
    // A popup is never raised onto the keyboard, whoever asks: that is what its
    // role means, and a caller that passes `inactive: false` to a popup is
    // describing a focus change it cannot have.
    final keepBack = inactive || !role.takesFocusOnShow;
    if (keepBack) {
      window.showInactive();
    } else {
      window
        ..show()
        ..focus();
    }
    _emit(WindowEvent.restored);
  }

  @override
  Future<void> hide() async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.hide();
    _emit(WindowEvent.hidden);
  }

  @override
  Future<void> minimize() async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.minimize();
  }

  @override
  Future<void> restore() async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.restore();
    _emit(WindowEvent.restored);
  }

  @override
  Future<bool> toggleMaximize() async {
    final window = await _windowForVerb();
    if (window == null) return false;
    if (window.isMaximized) {
      window.unmaximize();
      return false;
    }
    window.maximize();
    return true;
  }

  @override
  Future<bool> isMaximized() async => _windowOrNull?.isMaximized ?? false;

  @override
  Future<void> setPreventClose({required bool enabled}) async {
    // The object API has no prevent-close flag: close requests always pass
    // through the window's listeners, and the veto lives in `_onEvent`. This
    // only arms it; the pairing with `destroy()`'s `_destroying` guard is what
    // lets the shell's own quit land.
    _preventClose = enabled;
  }

  @override
  Future<void> close() async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.close();
  }

  @override
  Future<void> destroy() async {
    // The `_destroying` guard tells the close-request listener to stand down,
    // which is how a prevent-close window still dies when the shell has
    // decided to quit.
    _destroying = true;
    final window = await _windowForVerb();
    window?.close();
    _alive = false;
    _emit(WindowEvent.closed);
  }

  @override
  Future<WindowGeometry> geometry() async {
    final window = _windowOrNull;
    if (window == null) {
      // Nothing registered yet: a zero frame says "unknown" louder than a
      // real rectangle read off the wrong window would.
      return WindowGeometry(frame: rectToFrame(Rect.zero), maximized: false);
    }
    final frame = rectToFrame(window.bounds.toRect());
    return WindowGeometry(
      frame: frame,
      // Asked of the window manager here rather than remembered from the last
      // event: move and size events cover interactive drags, but a window
      // maximised by the keyboard, by a snap edge or by another process
      // arrives with no such notice, and a stale `false` here stores the
      // maximised outer rectangle — overhang and all — as the size the
      // window should come back at.
      maximized: window.isMaximized,
      displayId: _screenRetrieverDisplays.displayHosting(frame, await _readDisplays()),
    );
  }

  @override
  Future<void> setGeometry(WindowGeometry geometry) async {
    final window = await _windowForVerb();
    if (window == null) return;
    // A maximised window is asked to be maximised rather than sized to the work
    // area: sizing it leaves the window manager outside its own maximised state,
    // so the restore button returns the wrong size and snap-to-edge stops
    // working on a window that is visibly full screen.
    if (geometry.maximized) {
      window.maximize();
      return;
    }
    window.bounds = frameToRect(geometry.frame).toNative();
  }

  @override
  Future<void> center() async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.center();
  }

  @override
  Future<void> setAlwaysOnTop({required bool value}) async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.isAlwaysOnTop = value;
  }

  @override
  Future<void> setResizable({required bool value}) async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.isResizable = value;
  }

  @override
  Future<void> setTitle(String value) async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.title = value;
  }

  @override
  Future<void> startDragging() async {
    final window = await _windowForVerb();
    if (window == null) return;
    window.startDragging();
  }

  @override
  Future<WindowState> snapshot() async {
    final window = _windowOrNull;
    final geometry = await this.geometry();
    return WindowState(
      geometry: geometry,
      isVisible: window?.isVisible ?? false,
      isFocused: window?.isFocused ?? false,
    );
  }

  /// Detaches from the plugin and closes the event stream.
  Future<void> dispose() async {
    final listener = _listener;
    if (listener != null) {
      wm.WindowManager.instance.removeListener(listener);
    }
    _alive = false;
    await _events.close();
  }

  void _emit(WindowEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}
