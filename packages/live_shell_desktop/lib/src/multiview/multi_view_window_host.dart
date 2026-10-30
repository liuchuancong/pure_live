import 'dart:async';

import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:live_shell/live_shell.dart';
import 'package:multiview_desktop/multiview_desktop.dart';

/// One OS view as `live_shell` sees a window.
///
/// Unlike the old `WindowManagerHost`, there is no identity oracle and no
/// per-engine registration to wait for: the view id names the window for its
/// whole life, and every verb goes straight to that id.
final class MultiViewWindowHost implements WindowHost, WindowListenerCallbacks {
  /// A host over [viewId], with the role the window was opened for.
  new({required this.viewId, required this.role}) {
    MultiViewDesktop.addListenerForView(viewId, this);
  }

  /// The plugin's public view id.
  final int viewId;

  @override
  final WindowRole role;

  final StreamController<WindowEvent> _events = StreamController<WindowEvent>.broadcast();
  bool _alive = true;

  MultiViewDesktop get _window => MultiViewDesktop.fromId(viewId);

  @override
  bool get isAlive => _alive;

  @override
  Stream<WindowEvent> get events => _events.stream;

  /// Stops listening. The window itself belongs to the plugin and is closed
  /// through [close]/[destroy], not through this method.
  void dispose() {
    MultiViewDesktop.removeListenerForView(viewId, this);
    unawaited(_events.close());
  }

  Rect get _bounds => _window.getBounds();

  WindowGeometry get _geometry {
    final bounds = _bounds;
    final display = _window.display();
    return WindowGeometry(
      frame: PixelRect(bounds.left.round(), bounds.top.round(), bounds.width.round(), bounds.height.round()),
      maximized: _window.isMaximized(),
      displayId: display.id,
      scaleFactor: (display.scaleFactor ?? 1).toDouble(),
    );
  }

  @override
  Future<void> show({bool inactive = false}) async {
    _window.show();
    if (!inactive && role.takesFocusOnShow) {
      _window.focus();
    }
    _emit(WindowEvent.restored);
  }

  @override
  Future<void> hide() async {
    _window.hide();
    _emit(WindowEvent.hidden);
  }

  @override
  Future<void> minimize() async => _window.minimize();

  @override
  Future<void> restore() async => _window.restore();

  @override
  Future<bool> toggleMaximize() async {
    if (_window.isMaximized()) {
      _window.unmaximize();
    } else {
      _window.maximize();
    }
    return _window.isMaximized();
  }

  @override
  Future<bool> isMaximized() async => _window.isMaximized();

  @override
  Future<void> setPreventClose({required bool enabled}) async {
    _window.setPreventClose(enabled);
  }

  @override
  Future<void> close() async {
    // A request, not a wait: with interception armed the plugin parks the
    // close until a listener decides, and the shell's decision is the thing
    // that actually closes (or hides) the window. Awaiting it here would leave
    // the quit path waiting on a close that only the quit path can complete.
    unawaited(_window.closeWindow());
  }

  @override
  Future<void> destroy() async {
    _window.setPreventClose(false);
    await _window.closeWindow();
  }

  @override
  Future<WindowGeometry> geometry() async => _geometry;

  @override
  Future<void> setGeometry(WindowGeometry geometry) async {
    final frame = geometry.frame;
    await _window.setSize(Size(frame.width.toDouble(), frame.height.toDouble()));
    await _window.setPosition(Offset(frame.left.toDouble(), frame.top.toDouble()));
    if (geometry.maximized) {
      _window.maximize();
    } else {
      _window.unmaximize();
    }
  }

  @override
  Future<void> center() async {
    await _window.center();
  }

  @override
  Future<void> setAlwaysOnTop({required bool value}) async => _window.setAlwaysOnTop(value);

  @override
  Future<void> setResizable({required bool value}) async => _window.setResizable(value);

  @override
  Future<void> setTitle(String value) async => _window.setTitle(value);

  @override
  Future<void> startDragging() async => _window.startDragging();

  @override
  Future<WindowState> snapshot() async => WindowState(
    geometry: _geometry,
    isVisible: _window.isVisible(),
    isFocused: _window.isFocused(),
    scaleFactor: (_window.display().scaleFactor ?? 1).toDouble(),
  );

  // --- WindowListenerCallbacks ------------------------------------------------

  @override
  FutureOr<bool> onWindowClose() {
    if (!role.ownsAppState) {
      // A secondary window has no shell to answer for it: letting the plugin's
      // cascade finish destroys this one window and nothing else.
      return true;
    }
    _emit(WindowEvent.closeRequested);
    // The primary's close is the shell's decision, and the plugin's own
    // fallback is not one of the answers: with `stayAliveMainWindow` it hides
    // the window instead of waiting for hide / minimise / quit. Aborting the
    // cascade leaves the window untouched until the shell acts through
    // [hide], [minimize] or [destroy].
    return false;
  }

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

  @override
  void onWindowResized() {}

  @override
  void onWindowMove() => _emit(WindowEvent.moved);

  @override
  void onWindowMoved() {}

  @override
  void onWindowEnterFullScreen() => _emit(WindowEvent.enteredFullScreen);

  @override
  void onWindowLeaveFullScreen() => _emit(WindowEvent.leftFullScreen);

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'close') {
      _alive = false;
      _emit(WindowEvent.closed);
    }
  }

  void _emit(WindowEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}
