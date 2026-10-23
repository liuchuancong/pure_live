import 'dart:async';

import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/src/displays.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Used for the one stateless calculation the reader performs over a frame.
const _screenRetrieverDisplays = ScreenRetrieverDisplays();

/// The main window, driven through `window_manager`'s object API.
///
/// `WindowManager.instance.getCurrent()` addresses exactly one window — the one
/// belonging to the current Flutter engine — which is why this class is the main
/// window's host, and a secondary window runs its own instance inside its own
/// engine instead of being controlled from here.
///
/// The listener is registered on [attach] and removed on [dispose], and that
/// pairing is not ceremony: the manager keeps a strong list, so a shell that
/// rebuilds its window (lightweight mode, a render failure) without removing
/// accumulates one listener per rebuild. Every event then reaches the dead hosts
/// too, and the first symptom is a caption button that toggles twice.
final class WindowManagerHost implements WindowHost {
  /// A host for [role], resolving displays through [readDisplays].
  new({required this.role, DisplayReader? readDisplays})
    : _readDisplays = readDisplays ?? const ScreenRetrieverDisplays().read {
    _events = StreamController<WindowEvent>.broadcast();
  }

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

  @override
  bool get isAlive => _alive;

  @override
  Stream<WindowEvent> get events => _events.stream;

  /// The current engine's window, asked for on every use rather than cached: a
  /// window the runner rebuilt (lightweight mode, a render failure) is a new
  /// native object, and a cached reference would dress the corpse.
  wm.Window get _window {
    final window = wm.WindowManager.instance.getCurrent();
    if (window == null) {
      throw StateError('the current engine owns no top-level window');
    }
    return window;
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

  /// The manager's global event stream, narrowed to this window and folded
  /// into `live_shell`'s vocabulary.
  ///
  /// Two words go quiet on this platform: docking has no native event, and an
  /// unmaximise arrives as the same restore event an unminimise does, so the
  /// consumer sees one `restored` for both — which is what the close policy
  /// and the geometry store actually act on.
  void _onEvent(wm.WindowEvent event) {
    if (event.windowId != _window.id) {
      return; // another engine's window; it runs its own host.
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
    // A popup is never raised onto the keyboard, whoever asks: that is what its
    // role means, and a caller that passes `inactive: false` to a popup is
    // describing a focus change it cannot have.
    final keepBack = inactive || !role.takesFocusOnShow;
    if (keepBack) {
      _window.showInactive();
    } else {
      _window
        ..show()
        ..focus();
    }
    _emit(WindowEvent.restored);
  }

  @override
  Future<void> hide() async {
    _window.hide();
    _emit(WindowEvent.hidden);
  }

  @override
  Future<void> minimize() async {
    _window.minimize();
  }

  @override
  Future<void> restore() async {
    _window.restore();
    _emit(WindowEvent.restored);
  }

  @override
  Future<bool> toggleMaximize() async {
    if (_window.isMaximized) {
      _window.unmaximize();
      return false;
    }
    _window.maximize();
    return true;
  }

  @override
  Future<bool> isMaximized() async => _window.isMaximized;

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
    _window.close();
  }

  @override
  Future<void> destroy() async {
    // The `_destroying` guard tells the close-request listener to stand down,
    // which is how a prevent-close window still dies when the shell has
    // decided to quit.
    _destroying = true;
    _window.close();
    _alive = false;
    _emit(WindowEvent.closed);
  }

  @override
  Future<WindowGeometry> geometry() async {
    final frame = rectToFrame(_window.bounds.toRect());
    return WindowGeometry(
      frame: frame,
      // Asked of the window manager here rather than remembered from the last
      // event: move and size events cover interactive drags, but a window
      // maximised by the keyboard, by a snap edge or by another process
      // arrives with no such notice, and a stale `false` here stores the
      // maximised outer rectangle — overhang and all — as the size the
      // window should come back at.
      maximized: _window.isMaximized,
      displayId: _screenRetrieverDisplays.displayHosting(frame, await _readDisplays()),
    );
  }

  @override
  Future<void> setGeometry(WindowGeometry geometry) async {
    // A maximised window is asked to be maximised rather than sized to the work
    // area: sizing it leaves the window manager outside its own maximised state,
    // so the restore button returns the wrong size and snap-to-edge stops
    // working on a window that is visibly full screen.
    if (geometry.maximized) {
      _window.maximize();
      return;
    }
    _window.bounds = frameToRect(geometry.frame).toNative();
  }

  @override
  Future<void> center() async {
    _window.center();
  }

  @override
  Future<void> setAlwaysOnTop({required bool value}) async {
    _window.isAlwaysOnTop = value;
  }

  @override
  Future<void> setResizable({required bool value}) async {
    _window.isResizable = value;
  }

  @override
  Future<void> setTitle(String value) async {
    _window.title = value;
  }

  @override
  Future<void> startDragging() async {
    _window.startDragging();
  }

  @override
  Future<WindowState> snapshot() async {
    final geometry = await this.geometry();
    return WindowState(geometry: geometry, isVisible: _window.isVisible, isFocused: _window.isFocused);
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
