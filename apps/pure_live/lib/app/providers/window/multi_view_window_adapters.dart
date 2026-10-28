import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:media_core_fullscreen/media_core_fullscreen.dart';
import 'package:media_core_pip/media_core_pip.dart';
import 'package:multiview_desktop/multiview_desktop.dart';

/// [FullscreenWindow] over one multiview view.
///
/// The old backend pinned a Win32 HWND because the process-wide lookup could
/// find the primary window. A view id is already the identity, so there is no
/// lookup to get wrong.
final class MultiViewFullscreenWindow implements FullscreenWindow {
  /// Drives the window with [viewId].
  const MultiViewFullscreenWindow(this.viewId);

  /// The plugin's public view id.
  final int viewId;

  MultiViewDesktop get _window => MultiViewDesktop.fromId(viewId);

  @override
  Future<bool> get isFullscreen async => _window.isFullScreen();

  @override
  Future<Rect> captureBounds() async {
    final bounds = _window.getBounds();
    return Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height);
  }

  @override
  Future<void> setFullscreen({required bool value, Rect? restoreBounds}) async {
    // The plugin remembers the frame the window left and puts it back itself.
    // Applying [restoreBounds] on top of that would resize the window a second
    // time inside one transition — two client-size changes, and the frame
    // between them has no picture to paint.
    _window.setFullScreen(value);
  }
}

/// [PipWindow] over one multiview view.
///
/// Everything the compact window needs is a per-view operation in the plugin:
/// bounds, z-order, resizability, aspect lock, taskbar visibility, title and
/// drag. No native handle is exposed or needed.
final class MultiViewPipWindow implements PipWindow {
  /// Drives the window with [viewId].
  MultiViewPipWindow(this.viewId);

  /// The plugin's public view id.
  final int viewId;

  MultiViewDesktop get _window => MultiViewDesktop.fromId(viewId);

  /// The window's own resize floor, read before the compact policy releases
  /// it.
  ///
  /// The policy only knows the floor its caller passed (a guess); the window
  /// itself knows the one it was created with, and leaving the compact window
  /// must put that back or the normal window can later be dragged smaller
  /// than the app ever allowed.
  Size? _normalMinimum;

  @override
  Future<PipWindowSnapshot> capture() async {
    _normalMinimum ??= _window.getMinimumSize();
    final bounds = _window.getBounds();
    return PipWindowSnapshot(
      bounds: Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height),
      alwaysOnTop: _window.isAlwaysOnTop(),
      resizable: _window.isResizable(),
      skipTaskbar: _window.isHideAppTabFromTaskbar(),
      title: _window.getTitle(),
      titleBarStyle: _window.getTitleBarStyle(),
    );
  }

  @override
  Future<void> applySmallWindow({
    required Size size,
    required Offset position,
    required double? aspectRatio,
    required bool alwaysOnTop,
    required bool resizable,
    required bool skipTaskbar,
    required String title,
  }) async {
    _window
      ..setAlwaysOnTop(alwaysOnTop)
      ..setResizable(resizable)
      ..hideCurrentAppTabFromTaskbar(skipTaskbar)
      ..setTitle(title)
      ..setTitleBarStyle(
        TitleBarStyle.hidden,
        closeVisibility: false,
        maximizeVisibility: false,
        minimizeVisibility: false,
      );
    await _window.setAspectRatio(aspectRatio ?? 0);
    await _window.setSize(size);
    await _window.setPosition(position);
  }

  @override
  Future<void> restore(PipWindowSnapshot snapshot) async {
    _window
      ..setAlwaysOnTop(snapshot.alwaysOnTop)
      ..setResizable(snapshot.resizable)
      ..hideCurrentAppTabFromTaskbar(snapshot.skipTaskbar)
      ..setTitle(snapshot.title)
      ..setTitleBarStyle(TitleBarStyle.hidden);
    await _window.setAspectRatio(0);
    await _window.setSize(snapshot.bounds.size);
    await _window.setPosition(snapshot.bounds.topLeft);
    // The floor the window was born with, not the policy's guess: the policy
    // released the minimum to shrink, and this is the only place that knows
    // what it was before.
    final floor = _normalMinimum;
    _normalMinimum = null;
    if (floor != null && !floor.isEmpty) _window.setMinimumSize(floor);
  }

  @override
  Future<void> setAlwaysOnTop({required bool value}) async => _window.setAlwaysOnTop(value);

  @override
  Future<void> setMinimumSize(Size size) async => _window.setMinimumSize(size);

  @override
  Future<void> setAspectRatio(double aspectRatio) async => await _window.setAspectRatio(aspectRatio);

  @override
  Future<void> startDragging() async => _window.startDragging();
}
