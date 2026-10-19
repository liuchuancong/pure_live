import 'dart:async';

import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/src/displays.dart';
import 'package:window_frame_kit/window_frame_kit.dart';

/// Used for the one stateless calculation the reader performs over a frame.
const _screenRetrieverDisplays = ScreenRetrieverDisplays();

/// The main window, driven through `window_manager`.
///
/// `window_manager` addresses exactly one window — the one belonging to the
/// current Flutter engine — which is why this class is the main window's host,
/// and a secondary window runs its own instance inside its own engine instead of
/// being controlled from here.
///
/// The listener is registered on [attach] and removed on [dispose], and that
/// pairing is not ceremony: the plugin keeps a strong list, so a shell that
/// rebuilds its window (lightweight mode, a render failure) without removing
/// accumulates one listener per rebuild. Every event then reaches the dead hosts
/// too, and the first symptom is a caption button that toggles twice.
final class WindowManagerHost with WindowListener implements WindowHost {
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

  @override
  bool get isAlive => _alive;

  @override
  Stream<WindowEvent> get events => _events.stream;

  /// Subscribes to the plugin. Calling it again does nothing.
  ///
  /// Guarded here rather than trusted to the plugin's listener collection:
  /// a duplicate registration means every event is delivered twice, and the
  /// close policy is not idempotent — two destroys, two quit records, two exits.
  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    windowManager.addListener(this);
  }

  @override
  Future<void> show({bool inactive = false}) async {
    // A popup is never raised onto the keyboard, whoever asks: that is what its
    // role means, and a caller that passes `inactive: false` to a popup is
    // describing a focus change it cannot have.
    final keepBack = inactive || !role.takesFocusOnShow;
    await windowManager.show(inactive: keepBack);
    if (!keepBack) {
      await windowManager.focus();
    }
    _emit(WindowEvent.restored);
  }

  @override
  Future<void> hide() async {
    await windowManager.hide();
    _emit(WindowEvent.hidden);
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> restore() async {
    await windowManager.restore();
    _emit(WindowEvent.restored);
  }

  @override
  Future<bool> toggleMaximize() async {
    final maximised = await windowManager.isMaximized();
    if (maximised) {
      await windowManager.unmaximize();
      return false;
    }
    await windowManager.maximize();
    return true;
  }

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> setPreventClose({required bool enabled}) => windowManager.setPreventClose(enabled);

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> destroy() async {
    await windowManager.destroy();
    _alive = false;
    _emit(WindowEvent.closed);
  }

  @override
  Future<WindowGeometry> geometry() async {
    final frame = rectToFrame(await windowManager.getBounds());
    return WindowGeometry(
      frame: frame,
      // Asked of the window manager here rather than remembered from the last
      // event: `window_manager` reports move and size changes for interactive
      // drags, but a window maximised by the keyboard, by a snap edge or by
      // another process arrives with no such notice, and a stale `false` here
      // stores the maximised outer rectangle — overhang and all — as the size the
      // window should come back at.
      maximized: await windowManager.isMaximized(),
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
      await windowManager.maximize();
      return;
    }
    await windowManager.setBounds(frameToRect(geometry.frame));
  }

  @override
  Future<void> center() => windowManager.center();

  @override
  Future<void> setAlwaysOnTop({required bool value}) => windowManager.setAlwaysOnTop(value);

  @override
  Future<void> setResizable({required bool value}) => windowManager.setResizable(value);

  @override
  Future<void> setTitle(String value) => windowManager.setTitle(value);

  @override
  Future<WindowState> snapshot() async {
    final geometry = await this.geometry();
    return WindowState(
      geometry: geometry,
      isVisible: await windowManager.isVisible(),
      isFocused: await windowManager.isFocused(),
    );
  }

  /// Detaches from the plugin and closes the event stream.
  Future<void> dispose() async {
    windowManager.removeListener(this);
    _alive = false;
    await _events.close();
  }

  @override
  void onWindowClose() => _emit(WindowEvent.closeRequested);

  @override
  void onWindowFocus() => _emit(WindowEvent.focused);

  @override
  void onWindowBlur() => _emit(WindowEvent.blurred);

  @override
  void onWindowMaximize() => _emit(WindowEvent.maximised);

  @override
  void onWindowUnmaximize() => _emit(WindowEvent.unmaximised);

  @override
  void onWindowMinimize() => _emit(WindowEvent.minimised);

  @override
  void onWindowRestore() => _emit(WindowEvent.restored);

  @override
  void onWindowResize() => _emit(WindowEvent.resized);

  /// The settled form of the same change.
  ///
  /// `WindowListener` gives every callback a no-op default, so forgetting this
  /// override does not fail — it just means the window's new size is never
  /// remembered. Which of the pair a platform actually sends differs (Windows
  /// debounces the settled one after the drag stops), so both are forwarded: the
  /// store already coalesces writes and the drag throttle tolerates an extra
  /// push, while a missing event costs the viewer their window position.
  @override
  void onWindowResized() => _emit(WindowEvent.resized);

  @override
  void onWindowMove() => _emit(WindowEvent.moved);

  @override
  void onWindowMoved() => _emit(WindowEvent.moved);

  @override
  void onWindowEnterFullScreen() => _emit(WindowEvent.enteredFullScreen);

  @override
  void onWindowLeaveFullScreen() => _emit(WindowEvent.leftFullScreen);

  @override
  void onWindowDocked() => _emit(WindowEvent.snapped);

  @override
  void onWindowUndocked() => _emit(WindowEvent.unsnapped);

  void _emit(WindowEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}
