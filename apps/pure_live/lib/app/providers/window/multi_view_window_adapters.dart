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
    _window.setFullScreen(value);
    if (!value && restoreBounds != null && !restoreBounds.isEmpty) {
      await _window.setSize(restoreBounds.size);
      await _window.setPosition(restoreBounds.topLeft);
    }
  }
}

/// [PipWindow] over one multiview view.
///
/// Everything the compact window needs is a per-view operation in the plugin:
/// bounds, z-order, resizability, aspect lock, taskbar visibility, title and
/// drag. No native handle is exposed or needed.
final class MultiViewPipWindow implements PipWindow {
  /// Drives the window with [viewId].
  const MultiViewPipWindow(this.viewId);

  /// The plugin's public view id.
  final int viewId;

  MultiViewDesktop get _window => MultiViewDesktop.fromId(viewId);

  @override
  Future<PipWindowSnapshot> capture() async {
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
